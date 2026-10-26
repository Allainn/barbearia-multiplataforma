package com.barbearia.bff.infrastructure.auth;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnExpression;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.AnonymousAuthenticationFilter;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.List;

/**
 * Modo bypass, só para desenvolvimento local sem Keycloak: ativa quando KEYCLOAK_URL está
 * vazio. Toda requisição passa a ser de um usuário fixo com as roles cliente e gestor, e a
 * mesma matriz de RegrasDeAutorizacao continua valendo. O compose sempre define
 * KEYCLOAK_URL, então este modo nunca sobe no ambiente integrado.
 */
@Configuration
@EnableWebSecurity
@ConditionalOnExpression("'${bff.keycloak.url:}'.isBlank()")
public class BypassSecurityConfig {

    private static final Logger log = LoggerFactory.getLogger(BypassSecurityConfig.class);

    static final String USUARIO_BYPASS = "usuario-bypass";

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http, RespostasDeSeguranca respostas) throws Exception {
        log.warn("KEYCLOAK_URL vazio: autenticação DESLIGADA. Toda requisição é do usuário '{}' com as roles cliente e gestor.",
                USUARIO_BYPASS);
        http
                .csrf(AbstractHttpConfigurer::disable)
                .sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .addFilterBefore(new UsuarioFixoFilter(), AnonymousAuthenticationFilter.class)
                .authorizeHttpRequests(RegrasDeAutorizacao::aplicar)
                .exceptionHandling(e -> e
                        .authenticationEntryPoint(respostas)
                        .accessDeniedHandler(respostas));
        return http.build();
    }

    /** Coloca o usuário fixo no contexto de segurança antes da autorização. */
    static final class UsuarioFixoFilter extends OncePerRequestFilter {

        private static final List<SimpleGrantedAuthority> ROLES = List.of(
                new SimpleGrantedAuthority("ROLE_" + RegrasDeAutorizacao.ROLE_CLIENTE),
                new SimpleGrantedAuthority("ROLE_" + RegrasDeAutorizacao.ROLE_GESTOR));

        @Override
        protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
                throws ServletException, IOException {
            Authentication usuario = UsernamePasswordAuthenticationToken.authenticated(USUARIO_BYPASS, null, ROLES);
            SecurityContextHolder.getContext().setAuthentication(usuario);
            chain.doFilter(request, response);
        }
    }
}
