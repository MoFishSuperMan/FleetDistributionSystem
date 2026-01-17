from django.shortcuts import render, redirect
from django.http import JsonResponse
from django.db import connection, transaction, IntegrityError
from django.db.models import Count, Q
from django.contrib import messages
from django.contrib.auth import authenticate, login as auth_login, logout as auth_logout
from django.contrib.auth.decorators import login_required
from django.contrib.auth.models import User
from django.views.decorators.csrf import csrf_exempt
from django.utils import timezone
import json
from .models import Vehicle, Driver, Order, ExceptionRecord, Fleet, Dispatcher, DistributionCenter, HistoryLog

VEHICLE_STATUS_LABELS = {
    "Idle": "空闲",
    "Busy": "运输中",
    "Loading": "装货中",
    "Maintenance": "维修中",
    "Exception": "异常",
}

ORDER_STATUS_LABELS = {
    "Pending": "待分配",
    "Loading": "装货中",
    "In-Transit": "运输中",
    "Delivered": "已完成",
}

EXCEPTION_TYPE_LABELS = {
    "Transit_Exception": "运输中异常",
    "Idle_Exception": "空闲异常",
}

HANDLE_STATUS_LABELS = {
    "Unprocessed": "未处理",
    "Processed": "已处理",
}

ROLE_LABELS = {
    "dispatcher": "调度主管",
    "driver": "司机",
}

# 辅助函数：统一返回JSON格式
def success_response(data=None, message="Success"):
    return JsonResponse({'code': 200, 'message': message, 'data': data})

def error_response(message="Error", code=400):
    return JsonResponse({'code': code, 'message': message})
# =============================================
# Admin helper
# =============================================

def _ensure_admin(request):
    """检查是否为超级管理员(配送中心管理员)"""
    if not request.user.is_authenticated:
        messages.info(request, "请先登录。")
        return redirect("admin_login")
    
    role = request.session.get("role")
    
    if role == "admin":
        return None
    
    messages.error(request, "您没有权限访问此页面。")
    return redirect("dashboard")
# =============================================
# Auth helpers
# =============================================

def _ensure_dispatcher(request):
    if not request.user.is_authenticated:
        messages.info(request, "请先登录。")
        return redirect("dispatcher_login")
    
    role = request.session.get("role")
    if role == "dispatcher":
        return None
    if role == "driver":
        messages.error(request, "当前为司机身份，无法访问该页面。")
        return redirect("driver_center")
    
    # Fallback if authenticated but no role in session
    return redirect("dispatcher_login")


def _ensure_driver(request):
    if not request.user.is_authenticated:
        messages.info(request, "请先登录。")
        return redirect("driver_login")

    role = request.session.get("role")
    if role == "driver":
        return None
    if role == "dispatcher":
        messages.error(request, "当前为调度主管身份，无法访问司机页面。")
        return redirect("dashboard")
    
    return redirect("driver_login")


# =============================================
# Auth pages
# =============================================

def dispatcher_login(request):
    if request.method == "POST":
        dispatcher_id = request.POST.get("dispatcher_id", "").strip()
        password = request.POST.get("password", "").strip()
        if not dispatcher_id or not password:
            messages.error(request, "请填写账号和密码。")
            return redirect("dispatcher_login")

        # Use Django authenticate with custom backend
        user = authenticate(request, username=dispatcher_id, password=password, role='dispatcher')
        
        if user is not None:
            auth_login(request, user)
            # Fetch details to store in session
            dispatcher = Dispatcher.objects.get(dispatcher_id=dispatcher_id)
            
            request.session["role"] = "dispatcher"
            request.session["user_id"] = dispatcher.dispatcher_id
            request.session["user_name"] = dispatcher.name
            request.session["fleet_id"] = dispatcher.fleet_id # Access ID directly
            messages.success(request, "登录成功。")
            return redirect("dashboard")
        else:
            messages.error(request, "账号或密码错误。")
            return redirect("dispatcher_login")

    return render(request, "managersystem/login_dispatcher.html")


def driver_login(request):
    if request.method == "POST":
        driver_id = request.POST.get("driver_id", "").strip()
        password = request.POST.get("password", "").strip()  # Changed to password
        # phone = request.POST.get("phone", "").strip() # Removed phone login

        if not driver_id or not password:
            messages.error(request, "请填写工号和密码。")
            return redirect("driver_login")

        # Use Django authenticate with custom backend
        user = authenticate(request, username=driver_id, password=password, role='driver')
        
        if user is not None:
            auth_login(request, user)
            # Fetch details
            driver = Driver.objects.get(driver_id=driver_id)
            
            request.session["role"] = "driver"
            request.session["user_id"] = driver.driver_id
            request.session["user_name"] = driver.name
            request.session["fleet_id"] = driver.fleet_id # Access ID directly
            messages.success(request, "登录成功。")
            return redirect("driver_center")
        else:
            messages.error(request, "工号或密码不正确。")
            return redirect("driver_login")

    return render(request, "managersystem/login_driver.html")


def admin_login(request):
    """管理员登录 - 硬编码验证"""
    if request.method == "POST":
        password = request.POST.get("password", "").strip()
        
        # 硬编码的管理员密码 (可以改为环境变量)
        ADMIN_PASSWORD = "admin123"
        
        if password == ADMIN_PASSWORD:
            # 创建一个虚拟的 Django User 用于认证
            user, created = User.objects.get_or_create(username="admin")
            # 显式指定使用 ModelBackend
            user.backend = 'django.contrib.auth.backends.ModelBackend'
            auth_login(request, user)
            
            request.session["role"] = "admin"
            request.session["user_id"] = "admin"
            request.session["user_name"] = "系统管理员"
            messages.success(request, "登录成功。")
            return redirect("admin_dashboard")
        else:
            messages.error(request, "密码错误。")
            return redirect("admin_login")
    
    return render(request, "managersystem/login_admin.html")


def logout(request):
    auth_logout(request)
    request.session.flush()
    messages.success(request, "已退出登录。")
    return redirect("admin_login")


# =============================================
# Admin Backend (配送中心管理员)
# =============================================

def admin_dashboard(request):
    """管理员后台 - 配送中心列表"""
    redirect_response = _ensure_admin(request)
    if redirect_response:
        return redirect_response
    
    # 获取所有配送中心及其统计信息
    centers = DistributionCenter.objects.all()
    center_stats = []
    
    for center in centers:
        fleets = Fleet.objects.filter(center=center)
        fleet_count = fleets.count()
        vehicle_count = Vehicle.objects.filter(fleet__center=center).count()
        driver_count = Driver.objects.filter(fleet__center=center).count()
        
        center_stats.append({
            'center': center,
            'fleet_count': fleet_count,
            'vehicle_count': vehicle_count,
            'driver_count': driver_count,
        })
    
    return render(request, "managersystem/admin_dashboard.html", {
        'center_stats': center_stats,
    })


def center_detail(request, center_id):
    """配送中心详情 - 车辆负载情况总览"""
    redirect_response = _ensure_admin(request)
    if redirect_response:
        return redirect_response
    
    try:
        center = DistributionCenter.objects.get(center_id=center_id)
    except DistributionCenter.DoesNotExist:
        messages.error(request, "配送中心不存在。")
        return redirect("admin_dashboard")
    
    # 获取该配送中心下的所有车队、车辆、主管信息
    vehicles = Vehicle.objects.filter(fleet__center=center).select_related(
        'fleet', 'fleet__dispatcher'
    ).order_by('fleet__fleet_id', 'plate_number')
    
    # 为每辆车添加状态标签和颜色类
    for vehicle in vehicles:
        vehicle.status_label = VEHICLE_STATUS_LABELS.get(vehicle.status, vehicle.status)
        
        # 根据状态分配颜色类
        if vehicle.status == 'Idle':
            vehicle.row_class = 'table-light'  # 白色
        elif vehicle.status == 'Busy' or vehicle.status == 'Loading':
            vehicle.row_class = 'table-success'  # 浅绿色(满载/运输中)
        elif vehicle.status == 'Exception':
            vehicle.row_class = 'table-danger'  # 浅红色(异常)
        elif vehicle.status == 'Maintenance':
            vehicle.row_class = 'table-warning'  # 黄色(维修)
        else:
            vehicle.row_class = ''
        
        # 获取车队的调度主管
        try:
            vehicle.dispatcher = vehicle.fleet.dispatcher
        except:
            vehicle.dispatcher = None
    
    # 统计数据
    stats = {
        'total_vehicles': vehicles.count(),
        'idle_count': vehicles.filter(status='Idle').count(),
        'busy_count': vehicles.filter(status__in=['Busy', 'Loading']).count(),
        'exception_count': vehicles.filter(status='Exception').count(),
        'maintenance_count': vehicles.filter(status='Maintenance').count(),
    }

    # 获取车队详细信息用于前端展示 (Grid + Modal)
    fleets = Fleet.objects.filter(center=center)
    fleets_data = []
    for fleet in fleets:
        # Get dispatcher
        dispatcher_info = "-"
        try:
            if hasattr(fleet, 'dispatcher'):
                d = fleet.dispatcher
                dispatcher_info = f"{d.name} ({d.dispatcher_id})"
        except:
             pass
        
        # Get drivers
        drivers = Driver.objects.filter(fleet=fleet).values('name', 'driver_id', 'phone', 'license_level')
        
        # Get vehicles (simple list for modal)
        fleet_vehicles = Vehicle.objects.filter(fleet=fleet).values('plate_number', 'status', 'max_weight', 'max_volume')
        fleet_vehicles_list = []
        for v in fleet_vehicles:
            v['status_display'] = VEHICLE_STATUS_LABELS.get(v['status'], v['status'])
            fleet_vehicles_list.append(v)
        
        fleets_data.append({
            'fleet_id': fleet.fleet_id,
            'fleet_name': fleet.fleet_name,
            'dispatcher': dispatcher_info,
            'drivers': list(drivers),
            'vehicles': fleet_vehicles_list
        })

    import json
    fleets_json = json.dumps(fleets_data, default=str)
    
    return render(request, "managersystem/center_detail.html", {
        'center': center,
        'vehicles': vehicles,
        'stats': stats,
        'fleets': fleets,
        'fleets_json': fleets_json,
    })

# =============================================
# Frontend pages
# =============================================

def landing_page(request):
    if request.session.get("role"):
        return redirect("dashboard")

    stats = {}
    stats_error = None
    try:
        stats = {
            "centers": DistributionCenter.objects.count(),
            "fleets": Fleet.objects.count(),
            "vehicles": Vehicle.objects.count(),
            "drivers": Driver.objects.count(),
            "orders": Order.objects.count(),
            "exceptions": ExceptionRecord.objects.count(),
            "active_orders": Order.objects.filter(status__in=["Pending", "Loading", "In-Transit"]).count(),
        }
    except Exception as exc:
        stats_error = f"统计信息加载失败：{exc}"

    return render(
        request,
        "managersystem/landing.html",
        {
            "stats": stats,
            "stats_error": stats_error,
        },
    )

def dashboard(request):
    redirect_response = _ensure_dispatcher(request)
    if redirect_response:
        return redirect_response

    dispatcher_fleet_id = request.session.get("fleet_id")
    vehicle_queryset = Vehicle.objects.all()
    driver_queryset = Driver.objects.all()
    exception_queryset = ExceptionRecord.objects.all()

    if dispatcher_fleet_id:
        vehicle_queryset = vehicle_queryset.filter(fleet_id=dispatcher_fleet_id)
        driver_queryset = driver_queryset.filter(fleet_id=dispatcher_fleet_id)
        exception_queryset = exception_queryset.filter(vehicle_plate__fleet_id=dispatcher_fleet_id)

    status_summary = {key: 0 for key in VEHICLE_STATUS_LABELS}
    for row in vehicle_queryset.values("status").annotate(total=Count("status")):
        status_summary[row["status"]] = row["total"]

    stats = {
        "total_vehicles": sum(status_summary.values()),
        "total_drivers": driver_queryset.count(),
        "pending_orders": Order.objects.filter(status="Pending").count(),
        "unprocessed_exceptions": exception_queryset.filter(handle_status="Unprocessed").count(),
    }

    weekly_alerts = []
    weekly_alert_error = None
    try:
        with connection.cursor() as cursor:
            cursor.execute(
                "SELECT plate_number, fleet_name, driver_name, exception_type, occur_time FROM VW_Weekly_Alert"
            )
            columns = [col[0] for col in cursor.description]
            weekly_alerts = [dict(zip(columns, row)) for row in cursor.fetchall()]
            for row in weekly_alerts:
                row["exception_type_label"] = EXCEPTION_TYPE_LABELS.get(
                    row.get("exception_type"), row.get("exception_type")
                )
        if dispatcher_fleet_id:
            fleet_name = Fleet.objects.filter(fleet_id=dispatcher_fleet_id).values_list("fleet_name", flat=True).first()
            if fleet_name:
                weekly_alerts = [row for row in weekly_alerts if row.get("fleet_name") == fleet_name]
    except Exception as exc:
        weekly_alert_error = f"读取视图失败：{exc}"

    status_summary_rows = [
        {"code": code, "label": label, "total": status_summary.get(code, 0)}
        for code, label in VEHICLE_STATUS_LABELS.items()
    ]

    return render(
        request,
        "managersystem/dashboard.html",
        {
            "status_summary": status_summary_rows,
            "stats": stats,
            "weekly_alerts": weekly_alerts,
            "weekly_alert_error": weekly_alert_error,
        },
    )


def vehicle_page(request):
    redirect_response = _ensure_dispatcher(request)
    if redirect_response:
        return redirect_response

    dispatcher_fleet_id = request.session.get("fleet_id")
    if request.method == "POST":
        action = request.POST.get("action")
        
        # 删除操作
        if action == "delete":
            plate_number = request.POST.get("plate_number")
            try:
                vehicle = Vehicle.objects.get(plate_number=plate_number)
                if dispatcher_fleet_id and str(vehicle.fleet_id) != str(dispatcher_fleet_id):
                    messages.error(request, "只能删除自己车队的车辆。")
                else:
                    vehicle.delete()
                    messages.success(request, f"车辆 {plate_number} 已删除。")
            except Vehicle.DoesNotExist:
                messages.error(request, "车辆不存在。")
            except Exception as exc:
                messages.error(request, f"删除失败：{exc}")
            return redirect("vehicle_page")
        
        # 编辑操作
        elif action == "edit":
            plate_number = request.POST.get("plate_number")
            fleet_id = request.POST.get("fleet_id", "").strip()
            max_weight = request.POST.get("max_weight", "").strip()
            max_volume = request.POST.get("max_volume", "").strip()
            status = request.POST.get("status", "Idle")
            
            try:
                vehicle = Vehicle.objects.get(plate_number=plate_number)
                if dispatcher_fleet_id and str(vehicle.fleet_id) != str(dispatcher_fleet_id):
                    messages.error(request, "只能修改自己车队的车辆。")
                else:
                    vehicle.fleet_id = fleet_id
                    vehicle.max_weight = max_weight
                    vehicle.max_volume = max_volume
                    vehicle.status = status
                    vehicle.save()
                    messages.success(request, f"车辆 {plate_number} 信息已更新。")
            except Vehicle.DoesNotExist:
                messages.error(request, "车辆不存在。")
            except Exception as exc:
                messages.error(request, f"修改失败：{exc}")
            return redirect("vehicle_page")
        
        # 新增操作（默认）
        else:
            plate_number = request.POST.get("plate_number", "").strip()
            fleet_id = request.POST.get("fleet_id", "").strip()
            max_weight = request.POST.get("max_weight", "").strip()
            max_volume = request.POST.get("max_volume", "").strip()
            status = request.POST.get("status", "Idle")

            if not plate_number or not fleet_id or not max_weight or not max_volume:
                messages.error(request, "请填写完整的车辆信息。")
                return redirect("vehicle_page")

            if dispatcher_fleet_id and str(fleet_id) != str(dispatcher_fleet_id):
                messages.error(request, "只能操作自己车队的车辆。")
                return redirect("vehicle_page")

            try:
                Vehicle.objects.create(
                    plate_number=plate_number,
                    fleet_id=fleet_id,
                    max_weight=max_weight,
                    max_volume=max_volume,
                    status=status or "Idle",
                )
                messages.success(request, "车辆创建成功。")
            except Exception as exc:
                messages.error(request, f"车辆创建失败：{exc}")
            return redirect("vehicle_page")

    fleet_filter = request.GET.get("fleet_id")
    status_filter = request.GET.get("status")

    vehicles = Vehicle.objects.select_related("fleet").all()
    fleets = Fleet.objects.all()
    if dispatcher_fleet_id:
        vehicles = vehicles.filter(fleet_id=dispatcher_fleet_id)
        fleets = fleets.filter(fleet_id=dispatcher_fleet_id)
    if fleet_filter:
        vehicles = vehicles.filter(fleet_id=fleet_filter)
    if status_filter:
        vehicles = vehicles.filter(status=status_filter)
    for vehicle in vehicles:
        vehicle.status_label = VEHICLE_STATUS_LABELS.get(vehicle.status, vehicle.status)

    return render(
        request,
        "managersystem/vehicles.html",
        {
            "vehicles": vehicles,
            "fleets": fleets,
            "status_choices": list(VEHICLE_STATUS_LABELS.items()),
            "fleet_filter": fleet_filter or "",
            "status_filter": status_filter or "",
        },
    )


def driver_page(request):
    redirect_response = _ensure_dispatcher(request)
    if redirect_response:
        return redirect_response

    dispatcher_fleet_id = request.session.get("fleet_id")
    if request.method == "POST":
        action = request.POST.get("action")
        
        # 删除操作
        if action == "delete":
            driver_id = request.POST.get("driver_id")
            try:
                driver = Driver.objects.get(driver_id=driver_id)
                if dispatcher_fleet_id and str(driver.fleet_id) != str(dispatcher_fleet_id):
                    messages.error(request, "只能删除自己车队的司机。")
                else:
                    driver.delete()
                    messages.success(request, f"司机 {driver_id} 已删除。")
            except Driver.DoesNotExist:
                messages.error(request, "司机不存在。")
            except Exception as exc:
                messages.error(request, f"删除失败：{exc}")
            return redirect("driver_page")
        
        # 编辑操作
        elif action == "edit":
            driver_id = request.POST.get("driver_id")
            name = request.POST.get("name", "").strip()
            license_level = request.POST.get("license_level", "").strip()
            phone = request.POST.get("phone", "").strip()
            fleet_id = request.POST.get("fleet_id", "").strip()
            
            try:
                driver = Driver.objects.get(driver_id=driver_id)
                if dispatcher_fleet_id and str(driver.fleet_id) != str(dispatcher_fleet_id):
                    messages.error(request, "只能修改自己车队的司机。")
                else:
                    driver.name = name
                    driver.license_level = license_level
                    driver.phone = phone or None
                    driver.fleet_id = fleet_id
                    # 设置操作人信息到CONTEXT_INFO
                    operator = request.session.get('user_id', 'Unknown')
                    with connection.cursor() as cursor:
                        cursor.execute("DECLARE @op VARBINARY(128) = CAST(%s AS VARBINARY(128)); SET CONTEXT_INFO @op;", [operator])
                    driver.save()
                    messages.success(request, f"司机 {driver_id} 信息已更新。")
            except Driver.DoesNotExist:
                messages.error(request, "司机不存在。")
            except Exception as exc:
                messages.error(request, f"修改失败：{exc}")
            return redirect("driver_page")
        
        # 新增操作（默认）
        else:
            driver_id = request.POST.get("driver_id", "").strip()
            name = request.POST.get("name", "").strip()
            license_level = request.POST.get("license_level", "").strip()
            phone = request.POST.get("phone", "").strip()
            fleet_id = request.POST.get("fleet_id", "").strip()

        if not driver_id or not name or not license_level or not fleet_id:
            messages.error(request, "请填写完整的司机信息。")
            return redirect("driver_page")

        if dispatcher_fleet_id and str(fleet_id) != str(dispatcher_fleet_id):
            messages.error(request, "只能操作自己车队的司机。")
            return redirect("driver_page")

        try:
            Driver.objects.create(
                driver_id=driver_id,
                name=name,
                password='123456',  # 默认密码
                license_level=license_level,
                phone=phone or None,
                fleet_id=fleet_id,
            )
            messages.success(request, "司机创建成功。")
            # 重定向到新司机所属车队的筛选页面，确保可以看到新创建的司机
            return redirect(f"{request.path}?fleet_id={fleet_id}")
        except Exception as exc:
            messages.error(request, f"司机创建失败：{exc}")
        return redirect("driver_page")

    fleet_filter = request.GET.get("fleet_id")
    drivers = Driver.objects.select_related("fleet").all()
    fleets = Fleet.objects.all()
    if dispatcher_fleet_id:
        drivers = drivers.filter(fleet_id=dispatcher_fleet_id)
        fleets = fleets.filter(fleet_id=dispatcher_fleet_id)
    if fleet_filter:
        drivers = drivers.filter(fleet_id=fleet_filter)

    return render(
        request,
        "managersystem/drivers.html",
        {
            "drivers": drivers,
            "fleets": fleets,
            "fleet_filter": fleet_filter or "",
        },
    )


def order_page(request):
    redirect_response = _ensure_dispatcher(request)
    if redirect_response:
        return redirect_response

    dispatcher_fleet_id = request.session.get("fleet_id")
    if request.method == "POST":
        action = request.POST.get("action")
        
        # 1. Update Status Action
        if action == "update_status":
            order_id = request.POST.get("order_id")
            new_status = request.POST.get("new_status")
            
            if not order_id or not new_status:
                messages.error(request, "参数不完整。")
            elif new_status not in ["In-Transit", "Delivered"]:
                messages.error(request, "状态无效。")
            else:
                try:
                    order = Order.objects.get(order_id=order_id)
                    # Permission check (optional but recommended)
                    # if dispatcher_fleet_id and ... check belonging ...

                    with transaction.atomic():
                        order.status = new_status
                        if new_status == "Delivered":
                            order.end_time = timezone.now()
                        order.save()
                    messages.success(request, f"运单 {order_id} 状态已更新。")
                except Order.DoesNotExist:
                     messages.error(request, "运单不存在。")
                except Exception as e:
                    messages.error(request, f"更新失败: {e}")
            return redirect("order_page")


        # 2. Allocation Action (Default or explicit)
        order_id = request.POST.get("order_id", "").strip()
        vehicle_plate = request.POST.get("vehicle_plate", "").strip()
        driver_id = request.POST.get("driver_id", "").strip()

        if not order_id or not vehicle_plate or not driver_id:
            messages.error(request, "请填写完整的分配信息。")
            return redirect("order_page")

        try:
            vehicle = Vehicle.objects.get(plate_number=vehicle_plate)
            driver = Driver.objects.get(driver_id=driver_id)
            if dispatcher_fleet_id:
                if str(vehicle.fleet_id) != str(dispatcher_fleet_id) or str(driver.fleet_id) != str(dispatcher_fleet_id):
                    messages.error(request, "只能为自己车队分配运单。")
                    return redirect("order_page")

            with transaction.atomic():
                order = Order.objects.get(order_id=order_id)
                order.vehicle_plate_id = vehicle_plate
                order.driver_id = driver_id
                order.status = "In-Transit"
                order.start_time = timezone.now()
                order.save()
            messages.success(request, "运单分配成功。")
        except (Vehicle.DoesNotExist, Driver.DoesNotExist):
            messages.error(request, "车辆或司机不存在。")
        except IntegrityError as exc:
            messages.error(request, f"分配失败：{exc}")
        except Order.DoesNotExist:
            messages.error(request, "运单不存在。")
        except Exception as exc:
            messages.error(request, f"分配失败：{exc}")
        return redirect("order_page")

    pending_orders = Order.objects.filter(status="Pending").order_by("order_id")
    recent_orders = Order.objects.select_related("vehicle_plate", "driver").order_by("-start_time", "-order_id")
    for order in pending_orders:
        order.status_label = ORDER_STATUS_LABELS.get(order.status, order.status)
    # logic moved to loop above

    vehicles = Vehicle.objects.order_by("plate_number")
    drivers = Driver.objects.order_by("driver_id")
    if dispatcher_fleet_id:
        # 显示本车队的运单 + 所有待分配运单 (Pending)
        recent_orders = recent_orders.filter(
            Q(vehicle_plate__fleet_id=dispatcher_fleet_id) | Q(status='Pending')
        )
        vehicles = vehicles.filter(fleet_id=dispatcher_fleet_id)
        drivers = drivers.filter(fleet_id=dispatcher_fleet_id)

    # recent_orders = recent_orders[:50] # Removed limit
    for order in recent_orders:
        order.status_label = ORDER_STATUS_LABELS.get(order.status, order.status)
        # 增加颜色类逻辑 - 对应用户需求：运输中黄色，已完成绿色
        if order.status == "Pending":
            order.row_class = ""
            order.badge_class = "bg-secondary"
        elif order.status == "Loading":
            order.row_class = "table-info" 
            order.badge_class = "bg-info text-dark"
        elif order.status == "In-Transit":
            order.row_class = "table-warning" # 黄色
            order.badge_class = "bg-warning text-dark"
        elif order.status == "Delivered":
            order.row_class = "table-success" # 绿色
            order.badge_class = "bg-success"
        else:
            order.row_class = ""
            order.badge_class = "bg-secondary"

    for vehicle in vehicles:
        vehicle.status_label = VEHICLE_STATUS_LABELS.get(vehicle.status, vehicle.status)

    return render(
        request,
        "managersystem/orders.html",
        {
            "pending_orders": pending_orders,
            "recent_orders": recent_orders,
            "vehicles": vehicles,
            "drivers": drivers,
        },
    )


def exception_page(request):
    redirect_response = _ensure_dispatcher(request)
    if redirect_response:
        return redirect_response

    dispatcher_fleet_id = request.session.get("fleet_id")
    if request.method == "POST":
        action = request.POST.get("action")
        
        # 1. Resolve Exception (Update Status)
        if action == "resolve":
            record_id = request.POST.get("record_id")
            if not record_id:
                 messages.error(request, "参数错误。")
            else:
                try:
                    record = ExceptionRecord.objects.get(record_id=record_id)
                    # Optional: Check fleet permission if needed
                    # if dispatcher_fleet_id and record.vehicle_plate.fleet_id != dispatcher_fleet_id: ...
                    
                    if record.handle_status == "Unprocessed":
                        record.handle_status = "Processed"
                        record.save()
                        messages.success(request, f"异常记录 {record_id} 已处理。")
                    else:
                        messages.info(request, "该记录已被处理。")
                except ExceptionRecord.DoesNotExist:
                    messages.error(request, "记录不存在。")
                except Exception as e:
                     messages.error(request, f"处理失败: {e}")
            return redirect("exception_page")

        # 2. Create Exception (Default)
        vehicle_plate = request.POST.get("vehicle_plate", "").strip()
        driver_id = request.POST.get("driver_id", "").strip()
        exception_type = request.POST.get("exception_type", "").strip()
        specific_event = request.POST.get("specific_event", "").strip()
        fine_amount = request.POST.get("fine_amount", "").strip()
        description = request.POST.get("description", "").strip()

        if not vehicle_plate or not driver_id or not exception_type:
            messages.error(request, "请填写完整的异常信息。")
            return redirect("exception_page")

        try:
            vehicle = Vehicle.objects.get(plate_number=vehicle_plate)
            driver = Driver.objects.get(driver_id=driver_id)
            if dispatcher_fleet_id:
                if str(vehicle.fleet_id) != str(dispatcher_fleet_id) or str(driver.fleet_id) != str(dispatcher_fleet_id):
                    messages.error(request, "只能录入自己车队的异常。")
                    return redirect("exception_page")

            ExceptionRecord.objects.create(
                vehicle_plate_id=vehicle_plate,
                driver_id=driver_id,
                exception_type=exception_type,
                specific_event=specific_event or None,
                fine_amount=fine_amount or 0,
                description=description or None,
                handle_status="Unprocessed",
            )
            messages.success(request, "异常记录成功。")
        except Exception as exc:
            messages.error(request, f"异常记录失败：{exc}")
        return redirect("exception_page")

    exceptions = ExceptionRecord.objects.select_related("vehicle_plate", "driver").order_by("-occur_time")
    vehicles = Vehicle.objects.order_by("plate_number")
    drivers = Driver.objects.order_by("driver_id")
    if dispatcher_fleet_id:
        exceptions = exceptions.filter(vehicle_plate__fleet_id=dispatcher_fleet_id)
        vehicles = vehicles.filter(fleet_id=dispatcher_fleet_id)
        drivers = drivers.filter(fleet_id=dispatcher_fleet_id)
    exceptions = exceptions[:50]
    for record in exceptions:
        record.exception_type_label = EXCEPTION_TYPE_LABELS.get(
            record.exception_type, record.exception_type
        )
        record.handle_status_label = HANDLE_STATUS_LABELS.get(
            record.handle_status, record.handle_status
        )

    return render(
        request,
        "managersystem/exceptions.html",
        {
            "exceptions": exceptions,
            "vehicles": vehicles,
            "drivers": drivers,
            "exception_types": list(EXCEPTION_TYPE_LABELS.items()),
        },
    )


def report_page(request):
    redirect_response = _ensure_dispatcher(request)
    if redirect_response:
        return redirect_response

    dispatcher_fleet_id = request.session.get("fleet_id")
    fleets = Fleet.objects.order_by("fleet_id")
    drivers = Driver.objects.order_by("driver_id")
    if dispatcher_fleet_id:
        fleets = fleets.filter(fleet_id=dispatcher_fleet_id)
        drivers = drivers.filter(fleet_id=dispatcher_fleet_id)

    fleet_report = None
    fleet_error = None
    driver_report = None
    driver_exceptions = None
    driver_error = None

    fleet_id = request.GET.get("fleet_id", "").strip()
    report_date = request.GET.get("report_date", "").strip()
    if fleet_id and report_date:
        if dispatcher_fleet_id and str(fleet_id) != str(dispatcher_fleet_id):
            fleet_error = "只能查询自己车队的报表。"
        else:
            try:
                # 适配 month input (YYYY-MM)，补充为 YYYY-MM-01
                full_date = report_date + "-01" if len(report_date) == 7 else report_date

                with connection.cursor() as cursor:
                    cursor.execute("EXEC SP_Calc_Fleet_Monthly_Report %s, %s", [fleet_id, full_date])
                    columns = [col[0] for col in cursor.description]
                    fleet_report = [dict(zip(columns, row)) for row in cursor.fetchall()]
            except Exception as exc:
                fleet_error = f"统计报表查询失败：{exc}"

    driver_id = request.GET.get("driver_id", "").strip()
    start_date = request.GET.get("start_date", "").strip()
    end_date = request.GET.get("end_date", "").strip()
    if driver_id and start_date and end_date:
        allowed_driver_ids = [str(d.driver_id) for d in drivers]
        if dispatcher_fleet_id and str(driver_id) not in allowed_driver_ids:
            driver_error = "只能查询自己车队的司机绩效。"
        else:
            try:
                with connection.cursor() as cursor:
                    cursor.execute("EXEC SP_Get_Driver_Performance %s, %s, %s", [driver_id, start_date, end_date])
                    summary_rows = cursor.fetchall()
                    summary_columns = [col[0] for col in cursor.description]
                    driver_report = [dict(zip(summary_columns, row)) for row in summary_rows]

                    driver_exceptions = []
                    if cursor.nextset():
                        detail_rows = cursor.fetchall()
                        if cursor.description:
                            detail_columns = [col[0] for col in cursor.description]
                            driver_exceptions = [dict(zip(detail_columns, row)) for row in detail_rows]
            except Exception as exc:
                driver_error = f"统计报表查询失败：{exc}"

    return render(
        request,
        "managersystem/reports.html",
        {
            "fleets": fleets,
            "drivers": drivers,
            "fleet_id": fleet_id,
            "report_date": report_date,
            "fleet_report": fleet_report,
            "fleet_error": fleet_error,
            "driver_id": driver_id,
            "start_date": start_date,
            "end_date": end_date,
            "driver_report": driver_report,
            "driver_exceptions": driver_exceptions,
            "driver_error": driver_error,
        },
    )

# =============================================
# 1. 车辆管理接口
# =============================================

def driver_center(request):
    redirect_response = _ensure_driver(request)
    if redirect_response:
        return redirect_response

def history_log_page(request):
    """
    Dispatcher: View audit logs from History_Log table.
    """
    # Role check
    if request.session.get('role') != 'dispatcher':
        messages.error(request, "您没有权限访问该页面。")
        return redirect('landing')

    dispatcher_fleet_id = request.session.get('fleet_id')
    if not dispatcher_fleet_id:
        messages.error(request, "无法获取您的车队信息。")
        return redirect('dispatcher_login')

    # Fetch logs.
    logs = HistoryLog.objects.all().order_by('-change_time')
    
    return render(request, 'managersystem/history_logs.html', {'logs': logs})


def driver_center(request):
    # Role check
    if request.session.get('role') != 'driver':
        return redirect('driver_login')
        
    driver_id = request.session.get("user_id")
    driver = Driver.objects.select_related("fleet").filter(driver_id=driver_id).first()
    if not driver:
        messages.error(request, "未找到司机信息，请重新登录。")
        return redirect("driver_login")

    # 处理运单完成操作
    if request.method == "POST":
        action = request.POST.get("action")
        if action == "complete_order":
            order_id = request.POST.get("order_id")
            try:
                order = Order.objects.get(order_id=order_id, driver_id=driver_id)
                if order.status == "In-Transit":
                    with connection.cursor() as cursor:
                        cursor.execute(
                            "UPDATE [Order] SET status = 'Delivered', end_time = GETDATE() WHERE Order_id = %s",
                            [order_id]
                        )
                    messages.success(request, f"运单 {order_id} 已标记为已完成。")
                else:
                    messages.warning(request, f"只能完成运输中的运单。当前状态：{order.status}")
            except Order.DoesNotExist:
                messages.error(request, "运单不存在或无权操作。")
            except Exception as e:
                messages.error(request, f"操作失败：{e}")
            return redirect("driver_center")

    start_date = request.GET.get("start_date", "").strip()
    end_date = request.GET.get("end_date", "").strip()
    performance_summary = None
    performance_exceptions = None
    performance_error = None

    if start_date and end_date:
        try:
            with connection.cursor() as cursor:
                cursor.execute("EXEC SP_Get_Driver_Performance %s, %s, %s", [driver_id, start_date, end_date])
                summary_rows = cursor.fetchall()
                summary_columns = [col[0] for col in cursor.description]
                performance_summary = [dict(zip(summary_columns, row)) for row in summary_rows]

                performance_exceptions = []
                if cursor.nextset():
                    detail_rows = cursor.fetchall()
                    if cursor.description:
                        detail_columns = [col[0] for col in cursor.description]
                        performance_exceptions = [dict(zip(detail_columns, row)) for row in detail_rows]
        except Exception as exc:
            performance_error = f"查询失败：{exc}"

    orders = (
        Order.objects.select_related("vehicle_plate")
        .filter(driver_id=driver_id)
        .order_by("-start_time", "-order_id")[:50]
    )
    for order in orders:
        order.status_label = ORDER_STATUS_LABELS.get(order.status, order.status)

    exceptions = (
        ExceptionRecord.objects.select_related("vehicle_plate")
        .filter(driver_id=driver_id)
        .order_by("-occur_time")[:50]
    )
    for record in exceptions:
        record.exception_type_label = EXCEPTION_TYPE_LABELS.get(
            record.exception_type, record.exception_type
        )
        record.handle_status_label = HANDLE_STATUS_LABELS.get(
            record.handle_status, record.handle_status
        )

    return render(
        request,
        "managersystem/driver_center.html",
        {
            "driver": driver,
            "orders": orders,
            "exceptions": exceptions,
            "start_date": start_date,
            "end_date": end_date,
            "performance_summary": performance_summary,
            "performance_exceptions": performance_exceptions,
            "performance_error": performance_error,
        },
    )

