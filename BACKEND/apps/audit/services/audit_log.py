from apps.audit.models import AuditLog


def log_audit_event(
    *,
    actor_user=None,
    action,
    entity,
    entity_id=None,
    metadata=None,
    ip_address=None,
    user_agent="",
):
    return AuditLog.objects.create(
        actor_user=actor_user,
        action=action,
        entity=entity,
        entity_id=entity_id,
        metadata=metadata or {},
        ip_address=ip_address,
        user_agent=(user_agent or "")[:500],
    )


log_action = log_audit_event
