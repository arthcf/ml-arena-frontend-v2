# ML Arena — Frontend

Interface web do **ML Arena**, uma ferramenta para registrar execuções ("runs") de modelos de
Machine Learning, acompanhar métricas e hiperparâmetros, e comparar dois runs lado a lado
(incluindo os gráficos de medido×previsto e resíduos gerados a partir do CSV enviado).

Projeto desenvolvido para a disciplina **Desenvolvimento de Software para Nuvem** (UFC). No
**Trabalho 2**, a aplicação inteira roda em containers com Docker Compose.

> **Para rodar a aplicação completa**, siga o README do backend:
> [ml-arena-backend-v2](https://github.com/arthcf/ml-arena-backend-v2#-começo-rápido). O
> `docker-compose.yaml` fica lá e constrói este frontend a partir deste repositório, clonado ao lado.

## Arquitetura: por que dois repositórios

A aplicação é dividida em dois serviços independentes:

- **`ml-arena-backend-v2`**: a API (FastAPI). Guarda os dados em PostgreSQL, armazena CSVs e
  gráficos no MinIO, processa o CSV de forma assíncrona num worker separado (RabbitMQ), autentica
  usuários via JWT, audita ações no DynamoDB e usa Redis como cache. É ele quem fala com toda a
  infraestrutura.
- **`ml-arena-frontend-v2`** (este repositório): só a interface — renderiza as telas e repassa as
  ações do usuário pra API do backend. Não guarda dados, não fala com banco, MinIO, fila ou
  DynamoDB diretamente, e não precisa de nenhuma credencial pra funcionar. No compose ele fica numa
  rede separada (`frontend-net`) onde só enxerga a API.

Essa separação permite que cada serviço escale e seja implantado de forma independente.

### Como os dois se comunicam

O frontend é um cliente HTTP da API: todas as chamadas (login, listar/criar/remover runs, upload
de CSV, comparação) são feitas pelo próprio servidor do frontend usando `httpx`, nunca pelo
JavaScript do navegador. Isso importa por dois motivos:

1. **Segurança**: o token JWT devolvido pela API no login fica guardado só na sessão do servidor
   (um cookie assinado, graças ao `SessionMiddleware` do Starlette) — o navegador nunca tem acesso
   direto a ele via JavaScript.
2. **Simplicidade**: como o navegador nunca chama a API diretamente, não é preciso configurar CORS
   no backend.

## Stack

- **FastAPI** + **Jinja2** para renderizar o HTML no servidor.
- **Bootstrap** via CDN para o layout — sem build step, sem `npm`/`webpack`.
- **JavaScript puro**, usado só na tela de comparação (`app/static/js/compare.js`), pra buscar os
  dados dos dois runs escolhidos e montar a tabela/plots sem recarregar a página.
- **httpx** como cliente HTTP assíncrono para falar com a API.
- **uv** para gerenciar dependências Python.

## Telas

| Rota | O que faz |
|---|---|
| `/register`, `/login`, `/logout` | Cadastro e autenticação. O token da API fica na sessão. |
| `/runs` | Lista os runs do usuário logado, com status (`created`/`processing`/`done`/`failed`). |
| `/runs/new` | Cria um run (algoritmo, hiperparâmetros, métricas) e, opcionalmente, já envia o CSV medido×previsto. |
| `/runs/{id}/upload` | Envia o CSV depois, para um run que já existe mas ainda não tem um. |
| `/compare` | Tela de comparação ("Model Battle"): escolhe dois runs, clica em **SUBMIT** e vê hiperparâmetros, métricas e os dois gráficos lado a lado. As imagens vêm de links pré-assinados do MinIO. |
| `/audit` | **Atividade**: as últimas ações do usuário, lidas do log de auditoria no DynamoDB. Se o DynamoDB estiver inacessível (credenciais do Learner Lab vencidas), mostra um aviso. |
| `/health` | Health check usado pelo compose. |

O upload de CSV dispara o processamento assíncrono no backend — o run fica `processing` até o
worker terminar de gerar os gráficos, e passa a `done` (ou `failed`, se o CSV não puder ser
processado). Enquanto um gráfico ainda não existe, a tela de comparação avisa em vez de mostrar
uma imagem quebrada.

## Configuração

No Docker Compose do backend, as duas variáveis vêm do `environment:` do serviço `frontend`
(`API_BASE_URL=http://api:8000` e `SECRET_KEY=${FRONTEND_SECRET_KEY}` do `.env` do backend). O
`.env` deste repositório só vale para rodar o frontend sozinho:

```bash
cp .env.example .env
```

| Variável | O que é |
|---|---|
| `API_BASE_URL` | Endereço da API do backend (ex.: `http://127.0.0.1:8000` rodando no host; `http://api:8000` dentro do compose). |
| `SECRET_KEY` | Chave usada só para assinar o cookie de sessão deste frontend (via `itsdangerous`). **Não é** a mesma chave que o backend usa para assinar o JWT — são segredos independentes, com finalidades diferentes. Gere com `python3 -c "import secrets; print(secrets.token_urlsafe(32))"`. |

## Como rodar

### Com Docker Compose (aplicação completa)

Veja o [README do backend](https://github.com/arthcf/ml-arena-backend-v2#-começo-rápido), que também
traz a arquitetura, os diagramas e os prints. Em resumo,
com os dois repositórios lado a lado: `cd ml-arena-backend-v2 && cp .env.example .env` (preencha) e
`docker compose up -d --build`. A aplicação abre em http://localhost:8001.

### Sozinho, com `uv` (desenvolvimento)

Com a API do backend rodando em `API_BASE_URL`:

```bash
uv sync
uv run fastapi dev app/main.py --port 8001
```

## Imagem Docker

O `Dockerfile` instala exatamente o `uv.lock` (`uv sync --frozen`), roda como usuário sem privilégios
(`app`) e deixa o cache do uv fora da imagem. O `.dockerignore` impede que `.env`, `.git` e `.venv`
entrem na imagem.

```bash
docker build -t ml-arena-frontend .
docker run --rm -p 8001:8001 -e API_BASE_URL=http://<endereço-da-api>:8000 -e SECRET_KEY=... ml-arena-frontend
```
