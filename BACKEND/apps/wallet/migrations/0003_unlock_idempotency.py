from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('wallet', '0002_seed_topup_packages'),
    ]

    operations = [
        migrations.AddField(
            model_name='wallettransaction',
            name='idempotency_key',
            field=models.CharField(
                blank=True,
                max_length=64,
                null=True,
                unique=True,
                verbose_name='Clave de idempotencia',
            ),
        ),
        migrations.AddConstraint(
            model_name='wallettransaction',
            constraint=models.UniqueConstraint(
                condition=models.Q(
                    ('transaction_type', 'UNLOCK'),
                    ('related_object_id__isnull', False),
                ),
                fields=(
                    'transaction_type',
                    'related_object_type',
                    'related_object_id',
                ),
                name='uniq_unlock_charge_per_related_object',
            ),
        ),
    ]
