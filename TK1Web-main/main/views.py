from django.shortcuts import render
from django.contrib.auth.models import User
from django.contrib.auth.forms import UserCreationForm, AuthenticationForm
from django.contrib.auth import authenticate, login, logout
from django.http import HttpResponseRedirect
from django.contrib.auth.decorators import login_required
from django.urls import reverse
import datetime
from rest_framework import generics
from .models import Venue
from .serializers import VenueSerializer


# Create your views here.
def show_login(request):
    if request.user.is_authenticated:
        return show_landing(request)
    if request.method == 'POST':
        form = AuthenticationForm(data=request.POST)
        if form.is_valid():
            user = form.get_user()
            login(request, user)
            response = HttpResponseRedirect(reverse("main:landing"))
            response.set_cookie('last_login', str(datetime.datetime.now()))
            return response
    else:
        form = AuthenticationForm(request)
    context = {'form': form}
    return render(request, "html.html", context)

def show_register(request):
    if request.user.is_authenticated:
        return show_landing(request)

    if request.method == "POST":
        form = UserCreationForm(request.POST)
        if form.is_valid():
            user = form.save()
            return HttpResponseRedirect(reverse("main:login"))
        else:
            # kirim form dengan error ke template
            return render(request, "html2.html", {"form": form})
    else:
        form = UserCreationForm()

    return render(request, "html2.html", {"form": form})



@login_required(login_url='/login')
def show_landing(request):
    return render(request, "html3.html")


@login_required(login_url='/login')
def show_catalog(request):
    return render(request, "html4.html")



def logged_out(request):
    logout(request)
    response = HttpResponseRedirect(reverse("main:login"))
    return response


class VenueListCreateView(generics.ListCreateAPIView):
    queryset = Venue.objects.all()
    serializer_class = VenueSerializer
