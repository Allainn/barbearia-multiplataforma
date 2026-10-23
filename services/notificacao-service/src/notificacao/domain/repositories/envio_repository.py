"""
Porta (interface) do repositório de envios — camada de Domínio.

Define o contrato; a implementação fica na camada de Infraestrutura.
Os use cases dependem desta interface, nunca da implementação concreta.
"""

from abc import ABC, abstractmethod

from notificacao.domain.entities.envio import Envio


class EnvioRepository(ABC):

    @abstractmethod
    def add(self, envio: Envio) -> bool:
        """
        Persiste o envio. Retorna False se o evento_id já foi registrado
        (evento repetido), sem gravar nada.
        """
        ...

    @abstractmethod
    def list_recent(self, limit: int) -> list[Envio]:
        """Retorna os últimos envios (mais recente primeiro)."""
        ...
