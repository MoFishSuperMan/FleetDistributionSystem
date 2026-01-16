from django.db import models

# =============================================
# 1. 配送中心 (Distribution_Center)
# =============================================
class DistributionCenter(models.Model):
    center_id = models.AutoField(primary_key=True, verbose_name="中心编号")
    center_name = models.CharField(max_length=50, verbose_name="中心名称")
    address = models.CharField(max_length=100, null=True, blank=True, verbose_name="地址")

    class Meta:
        db_table = 'Distribution_Center'
        managed = False  # 使用现有数据库表
        verbose_name = "配送中心"
        verbose_name_plural = verbose_name

    def __str__(self):
        return self.center_name


# =============================================
# 2. 车队 (Fleet)
# =============================================
class Fleet(models.Model):
    fleet_id = models.AutoField(primary_key=True, verbose_name="车队编号")
    fleet_name = models.CharField(max_length=50, verbose_name="车队名称")
    center = models.ForeignKey(DistributionCenter, on_delete=models.CASCADE, db_column='center_id', verbose_name="所属中心")

    class Meta:
        db_table = 'Fleet'
        managed = False
        verbose_name = "车队"
        verbose_name_plural = verbose_name

    def __str__(self):
        return self.fleet_name


# =============================================
# 3. 调度主管 (Dispatcher)
# =============================================
class Dispatcher(models.Model):
    dispatcher_id = models.CharField(max_length=20, primary_key=True, verbose_name="主管工号")
    name = models.CharField(max_length=50, verbose_name="姓名")
    password = models.CharField(max_length=50, verbose_name="密码")
    fleet = models.OneToOneField(Fleet, on_delete=models.CASCADE, db_column='fleet_id', verbose_name="所属车队")

    class Meta:
        db_table = 'Dispatcher'
        managed = False
        verbose_name = "调度主管"
        verbose_name_plural = verbose_name


# =============================================
# 4. 车辆 (Vehicle)
# =============================================
class Vehicle(models.Model):
    STATUS_CHOICES = [
        ('Idle', '空闲'),
        ('Busy', '运输中'),
        ('Maintenance', '维修中'),
        ('Exception', '异常'),
    ]

    plate_number = models.CharField(max_length=20, primary_key=True, verbose_name="车牌号")
    fleet = models.ForeignKey(Fleet, on_delete=models.CASCADE, db_column='fleet_id', verbose_name="所属车队")
    max_weight = models.DecimalField(max_digits=10, decimal_places=2, verbose_name="最大载重")
    max_volume = models.DecimalField(max_digits=10, decimal_places=2, verbose_name="最大容积")
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='Idle', verbose_name="车辆状态")

    class Meta:
        db_table = 'Vehicle'
        managed = False
        verbose_name = "车辆"
        verbose_name_plural = verbose_name

    def __str__(self):
        return self.plate_number


# =============================================
# 5. 司机 (Driver)
# =============================================
class Driver(models.Model):
    driver_id = models.CharField(max_length=20, primary_key=True, verbose_name="司机工号")
    name = models.CharField(max_length=50, verbose_name="姓名")
    password = models.CharField(max_length=50, verbose_name="密码")
    license_level = models.CharField(max_length=10, verbose_name="驾照等级")
    phone = models.CharField(max_length=20, null=True, blank=True, verbose_name="电话")
    fleet = models.ForeignKey(Fleet, on_delete=models.CASCADE, db_column='fleet_id', verbose_name="所属车队")

    class Meta:
        db_table = 'Driver'
        managed = False
        verbose_name = "司机"
        verbose_name_plural = verbose_name


# =============================================
# 6. 运单 (Order)
# =============================================
class Order(models.Model):
    STATUS_CHOICES = [
        ('Pending', '待处理'),
        ('Loading', '装货中'),
        ('In-Transit', '运输中'),
        ('Delivered', '已送达'),
    ]

    order_id = models.CharField(max_length=20, primary_key=True, db_column='Order_id', verbose_name="运单号")
    cargo_weight = models.DecimalField(max_digits=10, decimal_places=2, verbose_name="货物重量")
    cargo_volume = models.DecimalField(max_digits=10, decimal_places=2, verbose_name="货物体积")
    destination = models.CharField(max_length=100, verbose_name="目的地")
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='Pending', verbose_name="运单状态")
    
    # 外键允许为空，因为刚创建运单时可能未分配
    vehicle_plate = models.ForeignKey(Vehicle, on_delete=models.SET_NULL, null=True, blank=True, db_column='vehicle_plate', verbose_name="承运车辆")
    driver = models.ForeignKey(Driver, on_delete=models.SET_NULL, null=True, blank=True, db_column='driver_id', verbose_name="承运司机")
    
    start_time = models.DateTimeField(null=True, blank=True, verbose_name="发车时间")
    end_time = models.DateTimeField(null=True, blank=True, verbose_name="签收时间")

    class Meta:
        db_table = 'Order' # 注意：SQL Server 中表名是 Order
        managed = False
        verbose_name = "运单"
        verbose_name_plural = verbose_name


# =============================================
# 7. 异常记录 (Exception_Record)
# =============================================
class ExceptionRecord(models.Model):
    TYPE_CHOICES = [
        ('Transit_Exception', '运输中异常'),
        ('Idle_Exception', '空闲时异常'),
    ]
    HANDLE_CHOICES = [
        ('Unprocessed', '未处理'),
        ('Processed', '已处理'),
    ]

    record_id = models.BigAutoField(primary_key=True, verbose_name="记录ID")
    vehicle_plate = models.ForeignKey(Vehicle, on_delete=models.CASCADE, db_column='vehicle_plate', null=True, blank=True, verbose_name="涉事车辆")
    driver = models.ForeignKey(Driver, on_delete=models.CASCADE, db_column='driver_id', null=True, blank=True, verbose_name="涉事司机")
    occur_time = models.DateTimeField(auto_now_add=True, verbose_name="发生时间")
    exception_type = models.CharField(max_length=20, choices=TYPE_CHOICES, verbose_name="异常类型")
    specific_event = models.CharField(max_length=50, null=True, blank=True, verbose_name="具体事件")
    fine_amount = models.DecimalField(max_digits=10, decimal_places=2, default=0, verbose_name="罚款金额")
    handle_status = models.CharField(max_length=20, choices=HANDLE_CHOICES, default='Unprocessed', verbose_name="处理状态")
    description = models.CharField(max_length=200, null=True, blank=True, verbose_name="描述")

    class Meta:
        db_table = 'Exception_Record'
        managed = False
        verbose_name = "异常记录"
        verbose_name_plural = verbose_name


# =============================================
# 8. 历史日志 (History_Log)
# =============================================
class HistoryLog(models.Model):
    log_id = models.BigAutoField(primary_key=True, verbose_name="日志ID")
    table_name = models.CharField(max_length=50, verbose_name="表名")
    record_key = models.CharField(max_length=50, verbose_name="记录主键值")
    column_name = models.CharField(max_length=50, verbose_name="变更字段名")
    old_value = models.TextField(blank=True, null=True, verbose_name="旧值")
    new_value = models.TextField(blank=True, null=True, verbose_name="新值")
    change_time = models.DateTimeField(db_column='change_time', verbose_name="变更时间")
    operator = models.CharField(max_length=50, blank=True, null=True, verbose_name="操作人")

    class Meta:
        db_table = 'History_Log'
        managed = False
        verbose_name = "历史日志"
        verbose_name_plural = verbose_name

