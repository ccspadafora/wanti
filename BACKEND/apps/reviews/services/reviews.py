from django.db import transaction
from django.db.models import Avg
from django.utils import timezone

from apps.audit.services.audit_log import log_audit_event
from apps.common.constants import ContactOutcome, ReviewStatus, TransactionType
from apps.common.exceptions import ConflictError, PermissionError, ValidationError
from apps.common.services.settings_service import get_setting
from apps.reviews.models import Review, ReviewDispute
from apps.wallet.services.wallet import apply_transaction, get_or_create_wallet


@transaction.atomic
def create_review(contact_unlock, reviewer, reviewee, rating: int, comment='', tags=None) -> Review:
    if reviewer.id not in (contact_unlock.buyer_id, contact_unlock.seller_id):
        raise PermissionError()
    if reviewee.id not in (contact_unlock.buyer_id, contact_unlock.seller_id):
        raise ValidationError('Reviewee inválido')
    if reviewer.id == reviewee.id:
        raise ValidationError('No puedes calificarte a ti mismo')
    if contact_unlock.outcome == ContactOutcome.PENDING:
        raise ValidationError('Debes reportar el outcome antes de calificar')
    if not 1 <= int(rating) <= 5:
        raise ValidationError('Rating debe ser entre 1 y 5')
    if Review.objects.filter(contact_unlock=contact_unlock, reviewer=reviewer).exists():
        raise ConflictError('Ya calificaste este desbloqueo')

    review = Review.objects.create(
        contact_unlock=contact_unlock,
        reviewer=reviewer,
        reviewee=reviewee,
        rating=rating,
        comment=comment,
        tags=tags or [],
        status=ReviewStatus.PUBLISHED,
    )
    _check_review_reward(reviewer)
    log_audit_event(
        actor_user=reviewer,
        action='REVIEW_CREATED',
        entity='Review',
        entity_id=review.id,
        metadata={'rating': rating},
    )
    return review


def _check_review_reward(reviewer):
    threshold = get_setting('REVIEW_REWARD_THRESHOLD', 5)
    count = Review.objects.filter(reviewer=reviewer).count()
    if count > 0 and count % threshold == 0:
        wallet = get_or_create_wallet(reviewer)
        apply_transaction(
            wallet=wallet,
            transaction_type=TransactionType.REWARD,
            amount_wantis=1,
            related_object=reviewer,
            note=f'Recompensa {threshold} reseñas',
            created_by=reviewer,
        )


@transaction.atomic
def dispute_review(review: Review, disputed_by, reason: str) -> ReviewDispute:
    if review.reviewee_id != disputed_by.id:
        raise PermissionError()
    if hasattr(review, 'dispute'):
        raise ConflictError('La reseña ya fue impugnada')
    rd = ReviewDispute.objects.create(
        review=review,
        disputed_by=disputed_by,
        reason=reason,
    )
    review.status = ReviewStatus.UNDER_REVIEW
    review.save(update_fields=['status', 'updated_at'])
    log_audit_event(
        actor_user=disputed_by,
        action='REVIEW_DISPUTED',
        entity='Review',
        entity_id=review.id,
    )
    return rd


@transaction.atomic
def resolve_review_dispute(review_dispute: ReviewDispute, admin_user, keep: bool, note='') -> Review:
    review = review_dispute.review
    if keep:
        review.status = ReviewStatus.PUBLISHED
        review_dispute.status = ReviewDispute.Status.RESOLVED_KEPT
    else:
        review.status = ReviewStatus.REMOVED
        review_dispute.status = ReviewDispute.Status.RESOLVED_REMOVED
    review.save(update_fields=['status', 'updated_at'])
    review_dispute.resolved_by = admin_user
    review_dispute.resolved_at = timezone.now()
    review_dispute.admin_note = note
    review_dispute.save()
    return review


def get_user_rating(user):
    result = Review.objects.filter(
        reviewee=user,
        status=ReviewStatus.PUBLISHED,
    ).aggregate(avg=Avg('rating'))
    return result['avg']
