# Imagem do frontend (FastAPI + Jinja). Fala com a API pela rede do compose (API_BASE_URL).
FROM python:3.14-slim

# uv copiado da imagem oficial, com versão fixa (antes: `pip install uv`, sempre a mais nova).
COPY --from=ghcr.io/astral-sh/uv:0.9.17 /uv /usr/local/bin/uv

ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_PYTHON_DOWNLOADS=never \
    PYTHONUNBUFFERED=1

# Usuário sem privilégios: se alguém explorar a aplicação, não é root no container.
RUN useradd --create-home --uid 1000 app

WORKDIR /workspace

# Dependências primeiro (camada em cache enquanto pyproject.toml e uv.lock não mudam).
# --frozen: instala exatamente o que está no lock (build reproduzível).
COPY pyproject.toml uv.lock ./
# Cache mount: o cache de downloads do uv fica fora da imagem (antes ele entrava na camada
# e quase dobrava o tamanho), mas continua acelerando os próximos builds.
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-dev --no-install-project
ENV PATH="/workspace/.venv/bin:$PATH"

COPY . .

USER app

EXPOSE 8001

CMD ["fastapi", "run", "app/main.py", "--host", "0.0.0.0", "--port", "8001"]
