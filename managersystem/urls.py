from django.urls import path
from . import views

urlpatterns = [
    # Auth
    path('', views.landing_page, name='landing'),
    path('manager/login/', views.admin_login, name='admin_login'),
    path('dispatcher/login/', views.dispatcher_login, name='dispatcher_login'),
    path('driver/login/', views.driver_login, name='driver_login'),
    path('logout/', views.logout, name='logout'),

    # Admin Backend (配送中心管理员)
    path('manager/dashboard/', views.admin_dashboard, name='admin_dashboard'),
    path('manager/center/<int:center_id>/', views.center_detail, name='center_detail'),

    # Dispatcher pages
    path('dashboard/', views.dashboard, name='dashboard'),
    path('history/', views.history_log_page, name='history_log_page'),
    path('vehicles/', views.vehicle_page, name='vehicle_page'),
    path('drivers/', views.driver_page, name='driver_page'),
    path('orders/', views.order_page, name='order_page'),
    path('exceptions/', views.exception_page, name='exception_page'),
    path('reports/', views.report_page, name='report_page'),

    # Driver pages
    path('driver/center/', views.driver_center, name='driver_center'),
]
