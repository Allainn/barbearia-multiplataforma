# scripts

Scripts de operação e da demo. Rodar a partir da raiz do repositório, no WSL2 ou no Linux. O passo a passo completo está no [README da raiz](../README.md#como-rodar).

| Script | O que faz |
|---|---|
| `up.sh` | Prepara as pastas de `infra/data/`, sobe o Compose com build das imagens, espera o Keycloak e roda o `keycloak-seed.sh` |
| `down.sh` | Derruba os containers e preserva os dados locais |
| `keycloak-seed.sh` | Cria ou atualiza o realm `barbearia`, o client `bff-gateway`, as roles e os usuários de teste. Roda o `keycloak_seed.py` num container Python e pode ser repetido sem problema |
| `deploy.sh` | Baixa do GHCR a imagem que o pipeline publicou e recria só o `barbearia-service`, sem build local |
| `demo.sh` | Roteiro da apresentação, tudo pelo BFF: 401, 403, cadastro, consulta de horários, disputa com 201 e 409, evento no Kafka e cancelamento. Enter avança cada passo |
| `disputa.sh` | Só a disputa pelo mesmo horário: duas reservas iguais ao mesmo tempo, uma recebe 201 e a outra 409 |

Os scripts da demo precisam de `curl`; o `demo.sh` também usa o `jq`. Os dois usam o `date` do GNU, então rodam no Linux e no WSL.
