from django.db.models import Avg

from apps.common.constants import ReviewStatus
from apps.common.constants import UserRole
from apps.common.exceptions import PermissionError
from apps.reviews.models import Review, ReviewDispute


def get_user_rating(user):
    result = Review.objects.filter(
        reviewee=user,
        status=ReviewStatus.PUBLISHED,
    ).aggregate(avg=Avg('rating'))
    return result['avg']


def list_reviews_of_user(user):
    return Review.objects.filter(reviewee=user, status=ReviewStatus.PUBLISHED).order_by(
        '-created_at'
    )


def list_reviews_by_user(user):
    return Review.objects.filter(reviewer=user).order_by('-created_at')


def list_review_disputes_pending(actor_user):
    if actor_user.role not in (UserRole.ADMIN, UserRole.MODERATOR):
        raise PermissionError()
    return ReviewDispute.objects.filter(status=ReviewDispute.Status.OPEN).select_related(
        'review', 'disputed_by'
    )
