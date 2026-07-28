from abc import ABC, abstractmethod


class PaymentProvider(ABC):
    @abstractmethod
    def create_checkout(self, order) -> dict:
        raise NotImplementedError
