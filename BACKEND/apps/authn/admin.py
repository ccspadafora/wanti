from django.contrib import admin

from apps.authn.models import EmailVerificationToken, PasswordResetToken, PhoneOtp


@admin.register(EmailVerificationToken)
class EmailVerificationTokenAdmin(admin.ModelAdmin):
    list_display = ('user', 'expires_at', 'used_at', 'created_at')
    list_filter = ('used_at',)
    search_fields = ('user__email', 'token')
    readonly_fields = ('id', 'created_at', 'updated_at')


@admin.register(PhoneOtp)
class PhoneOtpAdmin(admin.ModelAdmin):
    list_display = ('user', 'channel', 'expires_at', 'attempts', 'verified_at', 'created_at')
    list_filter = ('channel', 'verified_at')
    search_fields = ('user__email',)
    readonly_fields = ('id', 'code_hash', 'created_at', 'updated_at')


@admin.register(PasswordResetToken)
class PasswordResetTokenAdmin(admin.ModelAdmin):
    list_display = ('user', 'expires_at', 'used_at', 'requested_ip', 'created_at')
    list_filter = ('used_at',)
    search_fields = ('user__email', 'token')
    readonly_fields = ('id', 'created_at', 'updated_at')
