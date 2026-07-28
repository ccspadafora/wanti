from apps.common.integrations.ai_images.base import AIImageProvider


class MockAIImageProvider(AIImageProvider):
    def generate_images(self, *, prompt: str, count: int = 3) -> list[dict]:
        return [
            {
                'image_url': f'https://placehold.co/800x600?text=Wanti+AI+{i + 1}',
                'source_prompt': prompt,
                'is_ai_generated': True,
            }
            for i in range(count)
        ]
