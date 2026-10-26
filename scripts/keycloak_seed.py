#!/usr/bin/env python3
"""Seed do Keycloak da plataforma (ADR-0009 e ADR-0014).

Cria ou atualiza, pela Admin REST API, tudo o que o contrato exige:

- realm `barbearia`;
- client `bff-gateway`, confidencial, com *direct access grants* e o mapper de
  audience que coloca `bff-gateway` no `aud` do access token;
- realm roles `cliente` e `gestor`;
- usuários de teste `cliente1`, `cliente2` e `gestor1`, cada um com a sua role.

É idempotente: consulta antes de criar, e atualiza o que já existe para o
estado desejado (inclusive a senha dos usuários). Pode rodar a cada subida do
ambiente.

Variáveis de ambiente:

- KEYCLOAK_URL             base do Keycloak (default http://keycloak:8080).
                           Aceita também a URL do realm usada pelo BFF
                           (http://keycloak:8080/realms/barbearia).
- KEYCLOAK_ADMIN           usuário admin do realm master (default admin).
- KEYCLOAK_ADMIN_PASSWORD  senha do admin (default admin).

Só usa a biblioteca padrão, para rodar num `python:3.12-slim` sem `pip install`.
"""

from __future__ import annotations

import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

# ---------------------------------------------------------------------------
# Contrato (docs/roadmap.md e docs/tarefas.md, seção Keycloak)
# ---------------------------------------------------------------------------

REALM = "barbearia"
CLIENT_ID = "bff-gateway"
CLIENT_SECRET = "bff-secret"
ROLES = ("cliente", "gestor")
USUARIOS = (
    {"username": "cliente1", "password": "cliente123", "role": "cliente", "firstName": "Cliente", "lastName": "Um"},
    {"username": "cliente2", "password": "cliente123", "role": "cliente", "firstName": "Cliente", "lastName": "Dois"},
    {"username": "gestor1", "password": "gestor123", "role": "gestor", "firstName": "Gestor", "lastName": "Um"},
)
EMAIL_DOMINIO = "barbearia.local"

TENTATIVAS_CONEXAO = 30
INTERVALO_CONEXAO_S = 2


def base_url_de(valor: str) -> str:
    """Aceita a base ou a URL do realm e devolve sempre a base, sem barra final."""
    return re.sub(r"/realms/[^/]+/?$", "", valor.strip()).rstrip("/")


KEYCLOAK_URL = base_url_de(os.environ.get("KEYCLOAK_URL", "http://keycloak:8080"))
ADMIN_USER = os.environ.get("KEYCLOAK_ADMIN", "admin")
ADMIN_PASSWORD = os.environ.get("KEYCLOAK_ADMIN_PASSWORD", "admin")


# ---------------------------------------------------------------------------
# Cliente mínimo da Admin REST API
# ---------------------------------------------------------------------------


class KeycloakAdmin:
    def __init__(self, base_url: str, usuario: str, senha: str) -> None:
        self.base_url = base_url
        self.token = self._obter_token(usuario, senha)

    def _obter_token(self, usuario: str, senha: str) -> str:
        """Token do admin no realm master. Tenta várias vezes: o Keycloak demora a subir."""
        url = f"{self.base_url}/realms/master/protocol/openid-connect/token"
        form = urllib.parse.urlencode(
            {"grant_type": "password", "client_id": "admin-cli", "username": usuario, "password": senha}
        ).encode()
        ultimo_erro: Exception | None = None
        for tentativa in range(1, TENTATIVAS_CONEXAO + 1):
            try:
                req = urllib.request.Request(url, data=form, method="POST")
                req.add_header("Content-Type", "application/x-www-form-urlencoded")
                with urllib.request.urlopen(req, timeout=10) as resp:
                    return json.load(resp)["access_token"]
            except urllib.error.HTTPError as e:
                if e.code in (401, 403):
                    raise SystemExit(f"Credenciais de admin recusadas pelo Keycloak ({e.code}).")
                ultimo_erro = e
            except (urllib.error.URLError, TimeoutError, ConnectionError) as e:
                ultimo_erro = e
            if tentativa == 1:
                print(f"Aguardando o Keycloak em {self.base_url} ...")
            time.sleep(INTERVALO_CONEXAO_S)
        raise SystemExit(f"Keycloak não respondeu em {TENTATIVAS_CONEXAO * INTERVALO_CONEXAO_S}s: {ultimo_erro}")

    def _request(self, method: str, path: str, body: dict | list | None = None) -> tuple[int, object | None, str | None]:
        """Devolve (status, json ou None, header Location ou None). 404 não é erro."""
        url = f"{self.base_url}/admin/realms{path}"
        data = json.dumps(body).encode() if body is not None else None
        req = urllib.request.Request(url, data=data, method=method)
        req.add_header("Authorization", f"Bearer {self.token}")
        if data is not None:
            req.add_header("Content-Type", "application/json")
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                conteudo = resp.read()
                corpo = json.loads(conteudo) if conteudo else None
                return resp.status, corpo, resp.headers.get("Location")
        except urllib.error.HTTPError as e:
            if e.code == 404:
                return 404, None, None
            detalhe = e.read().decode(errors="replace")
            raise SystemExit(f"{method} {url} -> {e.code}: {detalhe}")

    def get(self, path: str) -> object | None:
        status, corpo, _ = self._request("GET", path)
        return None if status == 404 else corpo

    def post(self, path: str, body: dict | list) -> str | None:
        """Devolve o id do recurso criado, lido do header Location, quando houver."""
        _, _, location = self._request("POST", path, body)
        return location.rstrip("/").rsplit("/", 1)[-1] if location else None

    def put(self, path: str, body: dict) -> None:
        self._request("PUT", path, body)


# ---------------------------------------------------------------------------
# Passos do seed
# ---------------------------------------------------------------------------


def log(acao: str, o_que: str) -> None:
    print(f"  [{acao:<10}] {o_que}")


def garantir_realm(kc: KeycloakAdmin) -> None:
    desejado = {
        "realm": REALM,
        "enabled": True,
        "displayName": "Barbearia",
        # Ambiente local roda em HTTP puro (ADR-0009). Em produção, "external" ou "all".
        "sslRequired": "none",
    }
    if kc.get(f"/{REALM}") is None:
        kc.post("", desejado)
        log("criado", f"realm {REALM}")
    else:
        kc.put(f"/{REALM}", desejado)
        log("atualizado", f"realm {REALM}")


def garantir_client(kc: KeycloakAdmin) -> str:
    """Client confidencial do BFF. Devolve o id interno (UUID) do client."""
    desejado = {
        "clientId": CLIENT_ID,
        "name": "BFF Gateway",
        "enabled": True,
        "protocol": "openid-connect",
        "publicClient": False,
        "secret": CLIENT_SECRET,
        # Sem front-end na primeira versão: só o password grant, para a demo com curl.
        "directAccessGrantsEnabled": True,
        "standardFlowEnabled": False,
        "implicitFlowEnabled": False,
        "serviceAccountsEnabled": False,
        "fullScopeAllowed": True,
    }
    existentes = kc.get(f"/{REALM}/clients?clientId={CLIENT_ID}") or []
    if not existentes:
        client_uuid = kc.post(f"/{REALM}/clients", desejado)
        log("criado", f"client {CLIENT_ID}")
    else:
        client_uuid = existentes[0]["id"]
        kc.put(f"/{REALM}/clients/{client_uuid}", {"id": client_uuid, **desejado})
        log("atualizado", f"client {CLIENT_ID}")
    if not client_uuid:
        raise SystemExit(f"Não foi possível obter o id do client {CLIENT_ID}.")
    return client_uuid


def garantir_mapper_audience(kc: KeycloakAdmin, client_uuid: str) -> None:
    """Coloca `bff-gateway` no `aud` do access token. Sem isso o BFF rejeita o token (ADR-0015)."""
    nome = f"audience-{CLIENT_ID}"
    desejado = {
        "name": nome,
        "protocol": "openid-connect",
        "protocolMapper": "oidc-audience-mapper",
        "consentRequired": False,
        "config": {
            "included.client.audience": CLIENT_ID,
            "access.token.claim": "true",
            "id.token.claim": "false",
            "introspection.token.claim": "true",
        },
    }
    mappers = kc.get(f"/{REALM}/clients/{client_uuid}/protocol-mappers/models") or []
    existente = next((m for m in mappers if m["name"] == nome), None)
    if existente is None:
        kc.post(f"/{REALM}/clients/{client_uuid}/protocol-mappers/models", desejado)
        log("criado", f"mapper {nome}")
    else:
        kc.put(f"/{REALM}/clients/{client_uuid}/protocol-mappers/models/{existente['id']}", {"id": existente["id"], **desejado})
        log("atualizado", f"mapper {nome}")


def garantir_roles(kc: KeycloakAdmin) -> dict[str, dict]:
    """Realm roles do ADR-0014. Devolve {nome: representação}, usada no vínculo com os usuários."""
    roles: dict[str, dict] = {}
    for nome in ROLES:
        role = kc.get(f"/{REALM}/roles/{nome}")
        if role is None:
            kc.post(f"/{REALM}/roles", {"name": nome, "description": f"Role {nome} da plataforma"})
            role = kc.get(f"/{REALM}/roles/{nome}")
            log("criado", f"role {nome}")
        else:
            log("ok", f"role {nome}")
        roles[nome] = role
    return roles


def garantir_usuarios(kc: KeycloakAdmin, roles: dict[str, dict]) -> None:
    for u in USUARIOS:
        desejado = {
            "username": u["username"],
            "email": f"{u['username']}@{EMAIL_DOMINIO}",
            "emailVerified": True,
            "enabled": True,
            "firstName": u["firstName"],
            "lastName": u["lastName"],
            "requiredActions": [],
        }
        existentes = kc.get(f"/{REALM}/users?username={u['username']}&exact=true") or []
        if not existentes:
            user_id = kc.post(f"/{REALM}/users", desejado)
            log("criado", f"usuário {u['username']}")
        else:
            user_id = existentes[0]["id"]
            kc.put(f"/{REALM}/users/{user_id}", {"id": user_id, **desejado})
            log("atualizado", f"usuário {u['username']}")
        if not user_id:
            raise SystemExit(f"Não foi possível obter o id do usuário {u['username']}.")

        # Senha sempre redefinida: o seed é a fonte da verdade do ambiente local.
        kc.put(f"/{REALM}/users/{user_id}/reset-password", {"type": "password", "value": u["password"], "temporary": False})

        atuais = {r["name"] for r in (kc.get(f"/{REALM}/users/{user_id}/role-mappings/realm") or [])}
        if u["role"] not in atuais:
            role = roles[u["role"]]
            kc.post(f"/{REALM}/users/{user_id}/role-mappings/realm", [{"id": role["id"], "name": role["name"]}])
            log("vinculado", f"{u['username']} -> {u['role']}")
        else:
            log("ok", f"{u['username']} -> {u['role']}")


def main() -> int:
    print(f"Seed do Keycloak em {KEYCLOAK_URL} (realm {REALM})")
    kc = KeycloakAdmin(KEYCLOAK_URL, ADMIN_USER, ADMIN_PASSWORD)
    garantir_realm(kc)
    client_uuid = garantir_client(kc)
    garantir_mapper_audience(kc, client_uuid)
    roles = garantir_roles(kc)
    garantir_usuarios(kc, roles)
    print("Seed concluído.")
    print(f"Token: curl -s -X POST {KEYCLOAK_URL}/realms/{REALM}/protocol/openid-connect/token "
          f"-d grant_type=password -d client_id={CLIENT_ID} -d client_secret={CLIENT_SECRET} "
          f"-d username=cliente1 -d password=cliente123")
    return 0


if __name__ == "__main__":
    sys.exit(main())
