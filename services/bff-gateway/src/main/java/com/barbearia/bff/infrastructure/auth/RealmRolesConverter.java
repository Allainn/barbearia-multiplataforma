package com.barbearia.bff.infrastructure.auth;

import org.springframework.core.convert.converter.Converter;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.oauth2.jwt.Jwt;

import java.util.Collection;
import java.util.List;
import java.util.Map;

/**
 * Lê as realm roles do Keycloak (claim {@code realm_access.roles}) e as transforma nas
 * authorities {@code ROLE_<role>} que {@code hasRole("gestor")} espera. As roles vêm no
 * próprio token, então a decisão de autorização não consulta o Keycloak (ADR-0015).
 */
final class RealmRolesConverter implements Converter<Jwt, Collection<GrantedAuthority>> {

    private static final String PREFIXO = "ROLE_";

    @Override
    public Collection<GrantedAuthority> convert(Jwt jwt) {
        Map<String, Object> realmAccess = jwt.getClaimAsMap("realm_access");
        if (realmAccess == null || !(realmAccess.get("roles") instanceof Collection<?> roles)) {
            return List.of();
        }
        return roles.stream()
                .map(Object::toString)
                .<GrantedAuthority>map(role -> new SimpleGrantedAuthority(PREFIXO + role))
                .toList();
    }
}
