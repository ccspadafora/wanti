from django.apps import AppConfig


class CommonConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'apps.common'
    label = 'common'
    verbose_name = 'Configuración'

    def ready(self):
        from apps.common.admin_config import customize_admin

        customize_admin()
