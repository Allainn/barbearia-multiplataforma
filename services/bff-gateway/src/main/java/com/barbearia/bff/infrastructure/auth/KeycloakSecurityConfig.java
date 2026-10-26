package com.barbearia.bff.infrastructure.auth;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnExpression;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.oauth2.core.DelegatingOAuth2TokenValidator;
import org.springframework.security.oauth2.core.OAuth2TokenValidator;
import org.springframework.security.oauth2.jose.jws.SignatureAlgorithm;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtClaimNames;
import org.springframework.security.oauth2.jwt.JwtClaimValidator;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtValidators;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationConverter;
import org.springframework.security.web.SecurityFilterChain;

import java.util.Collection;

/**
 * Autenticação da requisição na borda (ADR-0015, opção A) com o JWT emitido pelo Keycloak
 * (ADR-0009). Ativa quando KEYCLOAK_URL está definido; sem ele, vale o BypassSecurityConfig.
 *
 * O que é verificado em cada requisição, nesta ordem: presença do Bearer token; assinatura
 * RS256 contra a chave pública do JWKS do realm (buscado sob demanda e mantido em cache pelo
 * Nimbus, com rotação pelo kid); exp e nbf; iss igual a KEYCLOAK_URL; aud contendo
 * KEYCLOAK_CLIENT_ID. Qualquer falha é 401. Passando, as roles de realm_access.roles viram
 * authorities e a matriz de RegrasDeAutorizacao decide o 403.
 */
@Configuration
@EnableWebSecurity
@ConditionalOnExpression("!'${bff.keycloak.url:}'.isBlank()")
public class KeycloakSecurityConfig {

    private static final Logger log = LoggerFactory.getLogger(KeycloakSecurityConfig.class);

    @Bean
    public JwtDecoder jwtDecoder(@Value("${bff.keycloak.url}") String issuer,
                                 @Value("${bff.keycloak.client-id}") String clientId) {
        // JWKS direto, sem OIDC discovery no boot: o BFF sobe mesmo se o Keycloak ainda não
        // responde, e a primeira requisição com token é que busca as chaves.
        NimbusJwtDecoder decoder = NimbusJwtDecoder.withJwkSetUri(issuer + "/protocol/openid-connect/certs")
                .jwsAlgorithm(SignatureAlgorithm.RS256)
                .build();

        OAuth2TokenValidator<Jwt> padraoComIssuer = JwtValidators.createDefaultWithIssuer(issuer);
        OAuth2TokenValidator<Jwt> audience = new JwtClaimValidator<Collection<String>>(
                JwtClaimNames.AUD, aud -> aud != null && aud.contains(clientId));
        decoder.setJwtValidator(new DelegatingOAuth2TokenValidator<>(padraoComIssuer, audience));

        log.info("Autenticação ligada: issuer {} e audience {}", issuer, clientId);
        return decoder;
    }

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http, JwtDecoder jwtDecoder,
                                                   RespostasDeSeguranca respostas) throws Exception {
        JwtAuthenticationConverter conversor = new JwtAuthenticationConverter();
        conversor.setJwtGrantedAuthoritiesConverter(new RealmRolesConverter());

        http
                // API stateless com Bearer token: não há sessão nem cookie, logo não há CSRF.
                .csrf(AbstractHttpConfigurer::disable)
                .sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .authorizeHttpRequests(RegrasDeAutorizacao::aplicar)
                .oauth2ResourceServer(oauth -> oauth
                        .jwt(jwt -> jwt.decoder(jwtDecoder).jwtAuthenticationConverter(conversor))
                        .authenticationEntryPoint(respostas)
                        .accessDeniedHandler(respostas))
                .exceptionHandling(e -> e
                        .authenticationEntryPoint(respostas)
                        .accessDeniedHandler(respostas));
        return http.build();
    }
}
