from django.contrib import admin


def customize_admin():
    admin.site.site_header = "Administración Wanti"
    admin.site.site_title = "Wanti"
    admin.site.index_title = "Panel de control"
    try:
        from django_celery_beat.models import (
            ClockedSchedule,
            CrontabSchedule,
            IntervalSchedule,
            PeriodicTask,
            PeriodicTasks,
            SolarSchedule,
        )

        for model in (
            ClockedSchedule,
            CrontabSchedule,
            IntervalSchedule,
            PeriodicTask,
            PeriodicTasks,
            SolarSchedule,
        ):
            try:
                admin.site.unregister(model)
            except admin.sites.NotRegistered:
                pass
    except ImportError:
        pass
