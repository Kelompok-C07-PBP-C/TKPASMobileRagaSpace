"""Forms related to authentication flows."""
from __future__ import annotations

from django import forms
from django.contrib.auth import get_user_model
from django.contrib.auth.forms import AuthenticationForm, UserCreationForm

from app.models import Profile


class LoginForm(AuthenticationForm):
    """Styled login form used across the site."""

    username = forms.CharField(
        widget=forms.TextInput(
            attrs={
                "class": "w-full rounded-xl bg-white/10 border border-white/30 px-4 py-3 text-white placeholder-white/60 backdrop-blur",
                "placeholder": "Username",
            }
        )
    )
    password = forms.CharField(
        widget=forms.PasswordInput(
            attrs={
                "class": "w-full rounded-xl bg-white/10 border border-white/30 px-4 py-3 text-white placeholder-white/60 backdrop-blur",
                "placeholder": "Password",
            }
        )
    )


class RegistrationForm(UserCreationForm):
    """Public user registration form."""

    email = forms.EmailField(
        required=False,
        widget=forms.EmailInput(
            attrs={
                "class": "w-full rounded-xl bg-white/10 border border-white/30 px-4 py-3 text-white placeholder-white/60 backdrop-blur",
                "placeholder": "Email (optional)",
            }
        ),
    )
    password1 = forms.CharField(
        label="Password",
        widget=forms.PasswordInput(
            attrs={
                "class": "w-full rounded-xl bg-white/10 border border-white/30 px-4 py-3 text-white placeholder-white/60 backdrop-blur",
                "placeholder": "Password",
            }
        ),
    )
    password2 = forms.CharField(
        label="Confirm Password",
        widget=forms.PasswordInput(
            attrs={
                "class": "w-full rounded-xl bg-white/10 border border-white/30 px-4 py-3 text-white placeholder-white/60 backdrop-blur",
                "placeholder": "Confirm Password",
            }
        ),
    )

    class Meta(UserCreationForm.Meta):
        model = get_user_model()
        fields = ("username", "email")
        widgets = {
            "username": forms.TextInput(
                attrs={
                    "class": "w-full rounded-xl bg-white/10 border border-white/30 px-4 py-3 text-white placeholder-white/60 backdrop-blur",
                    "placeholder": "Username",
                }
            ),
            "email": forms.EmailInput(
                attrs={
                    "class": "w-full rounded-xl bg-white/10 border border-white/30 px-4 py-3 text-white placeholder-white/60 backdrop-blur",
                    "placeholder": "Email (optional)",
                }
            ),
        }


class AdminCreationForm(UserCreationForm):
    """Form used by administrators to create fellow admins."""

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        for field in self.fields.values():
            widget = field.widget
            if isinstance(widget, forms.Select):
                existing_classes = widget.attrs.get("class", "")
                if "custom-select" not in existing_classes.split():
                    widget.attrs["class"] = (existing_classes + " custom-select").strip()

    password1 = forms.CharField(
        label="Password",
        widget=forms.PasswordInput(
            attrs={
                "class": "w-full rounded-xl border border-white/30 bg-white/10 px-4 py-3 text-white placeholder-white/60 backdrop-blur",
                "placeholder": "Password",
            }
        ),
    )
    password2 = forms.CharField(
        label="Confirm Password",
        widget=forms.PasswordInput(
            attrs={
                "class": "w-full rounded-xl border border-white/30 bg-white/10 px-4 py-3 text-white placeholder-white/60 backdrop-blur",
                "placeholder": "Confirm Password",
            }
        ),
    )

    class Meta(UserCreationForm.Meta):
        model = get_user_model()
        fields = ("username",)
        widgets = {
            "username": forms.TextInput(
                attrs={
                    "class": "w-full rounded-xl border border-white/30 bg-white/10 px-4 py-3 text-white placeholder-white/60 backdrop-blur",
                    "placeholder": "Username",
                }
            )
        }

    def save(self, commit: bool = True):
        user = super().save(commit=False)
        user.is_staff = True
        user.is_superuser = True
        if commit:
            user.save()
        return user


class ProfileUpdateForm(forms.ModelForm):
    """Update the authenticated user's profile + linked phone number."""

    phone_number = forms.CharField(
        required=False,
        widget=forms.TextInput(
            attrs={
                "class": "w-full rounded-xl bg-white/10 border border-white/30 px-4 py-3 text-white placeholder-white/60 backdrop-blur",
                "placeholder": "Phone number (optional)",
            }
        ),
    )

    class Meta:
        model = get_user_model()
        fields = ("username", "email", "first_name", "last_name")
        widgets = {
            "username": forms.TextInput(
                attrs={
                    "class": "w-full rounded-xl bg-white/10 border border-white/30 px-4 py-3 text-white placeholder-white/60 backdrop-blur",
                    "placeholder": "Username",
                }
            ),
            "email": forms.EmailInput(
                attrs={
                    "class": "w-full rounded-xl bg-white/10 border border-white/30 px-4 py-3 text-white placeholder-white/60 backdrop-blur",
                    "placeholder": "Email (optional)",
                }
            ),
            "first_name": forms.TextInput(
                attrs={
                    "class": "w-full rounded-xl bg-white/10 border border-white/30 px-4 py-3 text-white placeholder-white/60 backdrop-blur",
                    "placeholder": "First name (optional)",
                }
            ),
            "last_name": forms.TextInput(
                attrs={
                    "class": "w-full rounded-xl bg-white/10 border border-white/30 px-4 py-3 text-white placeholder-white/60 backdrop-blur",
                    "placeholder": "Last name (optional)",
                }
            ),
        }

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        user = self.instance
        profile = getattr(user, "profile", None)
        if profile is None and user and getattr(user, "pk", None):
            profile, _ = Profile.objects.get_or_create(user=user)
        self.fields["phone_number"].initial = getattr(profile, "phone_number", "")

    def save(self, commit: bool = True):
        user = super().save(commit=commit)
        profile = getattr(user, "profile", None)
        if profile is None:
            profile, _ = Profile.objects.get_or_create(user=user)
        profile.phone_number = (self.cleaned_data.get("phone_number") or "").strip()
        profile.save(update_fields=["phone_number"])
        return user
