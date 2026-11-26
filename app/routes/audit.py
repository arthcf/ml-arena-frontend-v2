"""Tela "Atividade": as últimas ações do usuário, gravadas no DynamoDB.

A API consulta a tabela de auditoria (só os logs do próprio usuário). Se o DynamoDB estiver
fora (ex.: credenciais do Learner Lab vencidas), a API responde 503 e a tela mostra o aviso
em vez de redirecionar: o handler geral de ApiError voltaria para esta mesma página.
"""

from fastapi import APIRouter, Request

from app.auth_guard import require_token
from app.services import api_client
from app.services.api_client import ApiError
from app.templates_engine import render

router = APIRouter(prefix="/audit")


@router.get("", name="audit_list")
async def list_audit(request: Request):
    token = require_token(request)
    try:
        logs = await api_client.list_audit(token)
        error = None
    except ApiError as exc:
        if exc.status_code == 401:
            raise  # sessão expirada: o handler geral manda para o login
        logs, error = [], exc.detail
    return render(request, "audit/list.html", {"logs": logs, "error": error})
