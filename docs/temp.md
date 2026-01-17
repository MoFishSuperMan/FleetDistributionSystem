
#### 4.2.2 运单分配以及自动载重校验

在运单分配模块中，主管可以对订单进行分配。分配过程中，系统会通过触发器机制，检查车辆的状态（如是否空闲、是否超载），如果超载了会进行相应的报错提示，确保每一次分配都符合业务规则，如下图所示：
<div>
<center>
<img src="asserts/image-10.png" width="49%" />
<img src="asserts/image-11.png" width="49%" />
<img src="asserts/image-12.png" width="49%" />
<img src="asserts/image-13.png" width="49%" />
</center>
</div>

#### 4.2.3 异常记录录入

在异常管理模块中，主管可以录入异常信息

<img src="asserts/image-15.png" width="49%" />
<img src="asserts/image-16.png" width="49%" />

#### 4.2.4 车队资源查询

在数据库管理员权限登录下，可以查看到所有配送中心的情况，然后点击'查看详情'可以查询某个配送中心下所有车队的车辆负载情况

<img src="asserts/image-26.png" width="49%" />
<img src="asserts/image-27.png" width="49%" />


#### 4.2.5 司机绩效追踪与统计报表

在统计报表页面，主管可以选择不同的时间范围来查看查询某名司机在特定时间段内的运输单数及产生的异常记录详情以及某个车队在某个月度的“安全与效率报表”，包含：总运单数、异常事件总数、累计罚款金额

<img src="asserts/image-30.png" width="49%" />


#### 4.2.6 车辆状态流转

当运单被分配后，车辆状态会自动从“空闲”变更为“运输中”；当运输完成后，车辆状态会自动变更为“维修中”或“空闲”，如下图所示：

<img src="asserts/image-13.png" width="49%" />
<img src="asserts/image-20.png" width="49%" />

<img src="asserts/image-23.png" width="49%" />
<img src="asserts/image-25.png" width="49%" />

当运输过程中录入异常后，车辆状态会自动变更为“异常”，然后当异常处理完成之后，，触发器自动根据异常类型将车辆状态从“异常”更新为“空闲”或“运输中”，如下图所示：

<img src="asserts/image-16.png" width="49%" />
<img src="asserts/image-17.png" width="49%" />

<img src="asserts/image-18.png" width="49%" />
<img src="asserts/image-20.png" width="49%" />


#### 4.2.7 审计日志

当修改司机的关键信息以及异常记录被处理时，触发器自动将旧数据写入 History_Log 表中进行备份：

<img src="asserts/image-7.png" width="49%" />
<img src="asserts/image-9.png" width="49%" />


<img src="asserts/image-16.png" width="49%" />
<img src="asserts/image-21.png" width="49%" />

#### 4.2.8 用户权限的分离以及系统总览

系统的总览首页如下，它显示了系统的基本信息以及各个模块的入口
![alt text](asserts/image.png)

然后系统有三种用户权限：数据库管理员、主管和司机，不同权限登录后看到的界面不同，功能也不同：

<img src="asserts/image-1.png" width="49%" />
<img src="asserts/image-4.png" width="49%" />

<img src="asserts/image-2.png" width="49%" />
<img src="asserts/image-26.png" width="49%" />

<img src="asserts/image-3.png" width="49%" />
<img src="asserts/image-22.png" width="49%" />