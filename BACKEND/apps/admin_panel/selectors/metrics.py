from datetime import timedelta
from decimal import Decimal

from django.db.models import Avg, Count, Sum
from django.utils import timezone

from apps.common.constants import (
    ContactOutcome,
    DisputeStatus,
    InventoryStatus,
    MatchStatus,
    NeedStatus,
    TopupStatus,
    UserStatus,
)
from apps.common.services.settings_service import get_setting
from apps.contacts.models import ContactUnlock
from apps.disputes.models import Dispute
from apps.inventory.models import InventoryItem
from apps.matching.models import Match
from apps.needs.models import Need
from apps.reviews.models import Review, ReviewDispute
from apps.users.models import User
from apps.wallet.models import TopupOrder, Wallet


def get_dashboard_metrics() -> dict:
    now = timezone.now()
    week_ago = now - timedelta(days=7)
    month_ago = now - timedelta(days=30)

    users_total = User.objects.count()
    users_active = User.objects.filter(status=UserStatus.ACTIVE).count()
    users_suspended = User.objects.filter(status=UserStatus.SUSPENDED).count()
    users_pending = User.objects.filter(status=UserStatus.PENDING).count()
    users_new = User.objects.filter(created_at__gte=week_ago).count()

    needs_total = Need.objects.count()
    needs_active = Need.objects.filter(status=NeedStatus.ACTIVE).count()
    needs_expired = Need.objects.filter(status=NeedStatus.EXPIRED).count()
    needs_fulfilled = Need.objects.filter(status=NeedStatus.FULFILLED).count()

    inventory_total = InventoryItem.objects.count()
    inventory_available = InventoryItem.objects.filter(
        status=InventoryStatus.AVAILABLE
    ).count()

    matches_week = Match.objects.filter(created_at__gte=week_ago).count()
    unlocked_week = Match.objects.filter(
        status=MatchStatus.UNLOCKED,
        unlocked_at__gte=week_ago,
    ).count()
    unlock_rate = (unlocked_week / matches_week) if matches_week else 0

    wantis_circulation = (
        Wallet.objects.aggregate(total=Sum('balance_wantis'))['total'] or 0
    )
    topup_cop = (
        TopupOrder.objects.filter(
            status=TopupStatus.COMPLETED,
            completed_at__gte=month_ago,
        ).aggregate(total=Sum('price_cop'))['total']
        or Decimal('0')
    )

    disputes_open = Dispute.objects.filter(status=DisputeStatus.OPEN).count()
    disputes_human = Dispute.objects.filter(status=DisputeStatus.HUMAN_REVIEW).count()
    disputes_resolved = Dispute.objects.filter(
        status__in=[DisputeStatus.APPROVED, DisputeStatus.REJECTED],
        resolved_at__gte=month_ago,
    ).count()
    approved = Dispute.objects.filter(
        status=DisputeStatus.APPROVED,
        resolved_at__gte=month_ago,
    ).count()
    approval_rate = (approved / disputes_resolved) if disputes_resolved else 0

    return {
        'users': {
            'total': users_total,
            'active': users_active,
            'suspended': users_suspended,
            'pending_verification': users_pending,
            'new_last_7_days': users_new,
        },
        'needs': {
            'total': needs_total,
            'active': needs_active,
            'expired': needs_expired,
            'fulfilled': needs_fulfilled,
        },
        'inventory': {
            'total_items': inventory_total,
            'available': inventory_available,
        },
        'matches': {
            'generated_last_7_days': matches_week,
            'unlocked_last_7_days': unlocked_week,
            'unlock_conversion_rate': round(unlock_rate, 3),
            'total': Match.objects.count(),
        },
        'wallet': {
            'total_wantis_in_circulation': wantis_circulation,
            'total_topup_cop_last_30_days': str(topup_cop),
            'topups_completed': TopupOrder.objects.filter(
                status=TopupStatus.COMPLETED
            ).count(),
        },
        'disputes': {
            'open': disputes_open,
            'in_human_review': disputes_human,
            'resolved_last_30_days': disputes_resolved,
            'approval_rate': round(approval_rate, 3),
        },
    }


def get_interactions_report(*, date_from=None, date_to=None) -> dict:
    qs_filters = {}
    if date_from:
        qs_filters['created_at__gte'] = date_from
    if date_to:
        qs_filters['created_at__lte'] = date_to

    needs_created = Need.objects.filter(**qs_filters).count()
    matches_generated = Match.objects.filter(**qs_filters).count()
    contacts_unlocked = ContactUnlock.objects.filter(**qs_filters).count()
    wantis_spent = (
        ContactUnlock.objects.filter(**qs_filters).aggregate(
            total=Sum('wantis_charged')
        )['total']
        or 0
    )
    reviews_created = Review.objects.filter(**qs_filters).count()
    disputes_opened = Dispute.objects.filter(**qs_filters).count()
    disputes_approved = Dispute.objects.filter(
        status=DisputeStatus.APPROVED,
        **({'resolved_at__gte': date_from} if date_from else {}),
        **({'resolved_at__lte': date_to} if date_to else {}),
    ).count()

    purchases = ContactUnlock.objects.filter(
        outcome=ContactOutcome.PURCHASED,
        **qs_filters,
    ).count()

    need_to_match = (
        round(matches_generated / needs_created * 100, 1) if needs_created else 0
    )
    match_to_unlock = (
        round(contacts_unlocked / matches_generated * 100, 1)
        if matches_generated
        else 0
    )
    unlock_to_purchase = (
        round(purchases / contacts_unlocked * 100, 1) if contacts_unlocked else 0
    )

    period = 'all time'
    if date_from or date_to:
        period = f'{date_from or "..."} to {date_to or "..."}'

    return {
        'period': period,
        'totals': {
            'needs_created': needs_created,
            'matches_generated': matches_generated,
            'contacts_unlocked': contacts_unlocked,
            'wantis_spent_on_unlocks': wantis_spent,
            'reviews_created': reviews_created,
            'disputes_opened': disputes_opened,
            'disputes_approved': disputes_approved,
        },
        'conversion_funnel': {
            'need_to_match_rate': str(need_to_match),
            'match_to_unlock_rate': str(match_to_unlock),
            'unlock_to_purchase_rate': str(unlock_to_purchase),
        },
    }


def get_matching_report() -> dict:
    high_threshold = get_setting('MATCH_HIGH_THRESHOLD', 85)
    min_score = get_setting('MATCH_MIN_SCORE', 50)

    high_count = Match.objects.filter(score__gte=high_threshold).count()
    mid_count = Match.objects.filter(
        score__gte=min_score,
        score__lt=high_threshold,
    ).count()
    avg_score = Match.objects.aggregate(avg=Avg('score'))['avg'] or 0
    needs_with_matches = (
        Need.objects.annotate(mc=Count('matches')).filter(mc__gt=0).count()
    )
    total_matches = Match.objects.count()
    avg_per_need = (total_matches / needs_with_matches) if needs_with_matches else 0

    return {
        'match_distribution': {
            'high_match_count': high_count,
            'mid_match_count': mid_count,
            'avg_score': round(float(avg_score), 1),
            'avg_matches_per_need': round(avg_per_need, 1),
        },
        'top_matched_criteria': [],
    }


def list_open_review_disputes():
    return (
        ReviewDispute.objects.filter(status=ReviewDispute.Status.OPEN)
        .select_related('review', 'disputed_by', 'review__reviewer', 'review__reviewee')
        .order_by('-created_at')
    )
