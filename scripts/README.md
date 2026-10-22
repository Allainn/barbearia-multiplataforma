# scripts

Scripts operacionais e da demo.

## Operação local

Executar a partir da raiz do repositório, no WSL2:

```bash
./scripts/up.sh
./scripts/down.sh
```

`up.sh` sobe o Compose com build das imagens e executa `keycloak-seed.sh` quando
esse arquivo existir. `down.sh` para os containers e preserva os dados locais.

## Deploy do `barbearia-service`

```bash
./scripts/deploy.sh
```

O script baixa a imagem publicada no GHCR e recria somente o
`barbearia-service`. O pipeline do GitHub Actions publica essa imagem; o script
não faz build local.

## Demo

Os scripts da demo (curl de 401/403, reserva e disputa 409) serão adicionados
conforme os serviços forem integrados.
