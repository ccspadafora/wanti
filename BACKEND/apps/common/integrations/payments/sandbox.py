from abc import ABC, abstractmethod


class PaymentProvider(ABC):
    @abstractmethod
    def create_checkout(self, order) -> dict:
        ...


class SandboxPaymentProvider(PaymentProvider):
    def create_checkout(self, order) -> dict:
        return {
            'checkout_url': f'https://sandbox.payments.local/pay/{order.id}',
            'provider_reference': f'sandbox-{order.id}',
        }


def get_payment_provider() -> PaymentProvider:
    return SandboxPaymentProvider()
