from rest_framework import status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from apps.common.exceptions import NotFoundError, ValidationError
from apps.common.pagination import StandardPagination
from apps.contacts.models import ContactUnlock
from apps.reviews.models import Review, ReviewTag
from apps.reviews.selectors.reviews import (
    get_user_rating,
    list_my_received_reviews,
    list_reviews_by_user,
    list_reviews_of_user,
)
from apps.reviews.serializers import (
    ReviewCreateSerializer,
    ReviewDisputeCreateSerializer,
    ReviewDisputeSerializer,
    ReviewPublicSerializer,
    ReviewSerializer,
    ReviewTagSerializer,
)
from apps.reviews.services.reviews import create_review, dispute_review
from apps.users.selectors.users import get_user_by_id


class ReviewTagsListView(APIView):
    permission_classes = [AllowAny]

    def get(self, request):
        qs = ReviewTag.objects.filter(is_active=True).order_by("for_role", "order")
        for_role = request.query_params.get("for_role")
        if for_role:
            qs = qs.filter(for_role=for_role)
        return Response(ReviewTagSerializer(qs, many=True).data)


class ReviewCreateView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, id):
        try:
            unlock = ContactUnlock.objects.select_related("buyer", "seller").get(pk=id)
        except ContactUnlock.DoesNotExist as exc:
            raise NotFoundError("Desbloqueo no encontrado") from exc
        serializer = ReviewCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        if request.user.id == unlock.buyer_id:
            reviewee = unlock.seller
        elif request.user.id == unlock.seller_id:
            reviewee = unlock.buyer
        else:
            reviewee = unlock.seller
        review = create_review(
            unlock,
            request.user,
            reviewee,
            rating=serializer.validated_data["rating"],
            comment=serializer.validated_data.get("comment", ""),
            tags=serializer.validated_data.get("tags") or [],
        )
        return Response(ReviewSerializer(review).data, status=status.HTTP_201_CREATED)


class UserReviewsListView(APIView):
    permission_classes = [AllowAny]

    def get(self, request, id):
        user = get_user_by_id(id)
        qs = list_reviews_of_user(user)
        paginator = StandardPagination()
        page = paginator.paginate_queryset(qs, request, view=self)
        data = ReviewPublicSerializer(page, many=True).data
        response = paginator.get_paginated_response(data)
        response.data["average_rating"] = get_user_rating(user)
        return response


class MyReviewsListView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        review_type = request.query_params.get("type", "received")
        if review_type == 'given':
            qs = list_reviews_by_user(request.user)
        elif review_type == 'received':
            qs = list_my_received_reviews(request.user)
        else:
            raise ValidationError('type debe ser given o received')
        paginator = StandardPagination()
        page = paginator.paginate_queryset(qs, request, view=self)
        return paginator.get_paginated_response(ReviewSerializer(page, many=True).data)


class ReviewDisputeView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, id):
        try:
            review = Review.objects.select_related("reviewee").get(pk=id)
        except Review.DoesNotExist as exc:
            raise NotFoundError("Reseña no encontrada") from exc
        serializer = ReviewDisputeCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        dispute = dispute_review(
            review, request.user, reason=serializer.validated_data["reason"]
        )
        return Response(
            ReviewDisputeSerializer(dispute).data, status=status.HTTP_201_CREATED
        )
