from django.contrib import admin
from django.urls import path
from vinahouse_app.views import get_products
from vinahouse_app.views import home

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/products/', get_products, name='get_products')
]
