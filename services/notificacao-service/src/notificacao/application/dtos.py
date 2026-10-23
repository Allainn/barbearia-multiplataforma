from datetime import datetime

from pydantic import BaseModel


class EnvioResponseDTO(BaseModel):
    id: str
    evento_id: str
    tipo: str
    cliente_id: str
    mensagem: str
    payload: dict
    enviado_em: datetime

    model_config = {"from_attributes": True}
