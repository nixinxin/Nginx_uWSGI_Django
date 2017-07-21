from django.shortcuts import render

# Create your views here.


# 默认页面就一个测试使用
def index(request):
    return render(request, 'index.html')

