from abc import ABC, abstractmethod


class AIImageProvider(ABC):
    @abstractmethod
    def generate_images(self, *, prompt: str, count: int = 3) -> list[dict]:
        pass


def generate_images(*, prompt: str, count: int = 3) -> list[dict]:
    from apps.common.integrations.ai_images.mock import MockAIImageProvider

    return MockAIImageProvider().generate_images(prompt=prompt, count=count)
