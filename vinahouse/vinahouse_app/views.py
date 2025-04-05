from django.shortcuts import render
from rest_framework.response import Response
from rest_framework.decorators import api_view
from .models import Product
from .serializers import ProductSerializer
from django.http import HttpResponse

@api_view(['GET'])
def get_products(request):
    try:
        products = Product.objects.all()  # Gán giá trị trước khi sử dụng
        serializer = ProductSerializer(products, many=True)
        return Response(serializer.data)
    except Exception as e:
        return Response({'error': str(e)}, status=500)
    
@api_view(['GET'])
def home(request):
    return HttpResponse("Chào mừng đến với Vinahouse!")

