# 智慧物流车队与配送管理数据库系统设计实验报告

## 0. 成员

| 学号 | 姓名 | 分工 | 
| :--- | :--- | :--- |
| 23320104 | 刘天翔 | 数据库设计(50%)、后端接口(100%)、触发器/存储过程(100%)、单元测试(100%)、实验报告的撰写（50%） |
| 23330154 | 杨毅涵 | 数据库设计(50%)、前端设计(100%)、索引的设计(100%)、实验报告的撰写（50%） |


## 1. 概念结构设计

### 1.1 实体集

根据题目所要求的需求，系统应该有一下的实体：

1.  **配送中心 (Distribution_Center)**
    物流网络的物理节点，负责管辖车队

    *   `center_id` (中心编号): 唯一标识 [PK]
    *   `center_name` (中心名称): 如“华东一号仓”
    *   `address` (地址): 物理位置
2.  **车队 (Fleet)**
    负责管理车辆与司机

    *   `fleet_id` (车队编号): 唯一标识 [PK]
    *   `fleet_name` (车队名称): 如“干线车队”
3.  **车辆 (Vehicle)**

    *   `plate_number` (车牌号): 唯一标识 [PK]
    *   `max_weight` (最大载重): 吨
    *   `max_volume` (最大容积): 立方米
    *   `status` (车辆状态): 枚举值 (Idle, Loading, Busy, Maintenance, Exception)
4.  **司机 (Driver)**

    *   `driver_id` (工号): 唯一标识 [PK]
    *   `name` (姓名)
    *   `license_level` (驾照等级): A1, A2, B1等
    *   `phone` (联系电话)
5.  **调度主管 (Dispatcher)**
    车队负责人，可以录入司机和车辆信息，分配运单，一个车队只有一个主管

    *   `dispatcher_id` (工号/账号): 唯一标识 [PK]
    *   `name` (姓名)
    *   `password` (登录密码): 用于系统认证
6.  **运单 (Order)**

    *   `Order_id` (运单号): 唯一标识 [PK]
    *   `cargo_weight` (货物重量)
    *   `cargo_volume` (货物体积)
    *   `destination` (目的地)
    *   `status` (运单状态): Pending, Loading, In-Transit, Delivered
    *   `start_time` (发车时间)
    *   `end_time` (签收时间)
7.  **异常记录 (Exception_Record)**
    运输、日常中的意外事件记录

    *   `record_id` (记录ID): 唯一标识 [PK]
    *   `occur_time` (发生时间)
    *   `exception_type` (异常类型): 核心枚举值 (Transit_Exception-运输中异常, Idle_Exception-空闲时异常) —— 决定车辆恢复状态
    *   `specific_event` (具体事件): 如货物破损、车辆故障、严重延误、超速报警等
    *   `fine_amount` (罚款金额)
    *   `handle_status` (处理状态): Unprocessed, Processed
    *   `description` (描述)

8.  **审计日志 (History_Log)**
    记录关键数据变更的历史信息，日志系统，使用触发器自动生成

    *   `log_id` (日志ID): 唯一标识 [PK]
    *   `table_name` (来源表名)
    *   `record_key` (记录主键)
    *   `column_name` (变更字段)
    *   `old_value` (旧值)
    *   `new_value` (新值)
    *   `change_time` (变更时间)
    *   `operator` (操作人)

### 1.2 关系集

1.  **辖属 (Center-Fleet)**: 1个配送中心下辖 N 个车队 (1:N)
2.  **拥有 (Fleet-Vehicle)**: 1个车队拥有 N 辆车 (1:N)
3.  **属于 (Fleet-Driver)**: 1个车队雇佣 N 名司机 (1:N)
4.  **管理 (Fleet-Dispatcher)**: 1个车队由 1 名主管管理 (1:1)
5.  **运输 (Vehicle-Order)**: 1辆车可以承运 N 个运单 (1:N)
6.  **驾驶 (Driver-Order)**: 1名司机负责 N 个运单 (1:N)
7.  **涉事车辆 (Exception-Vehicle)**: N 条异常关联 1 辆车 (N:1)
8.  **涉事司机 (Exception-Driver)**: N 条异常关联 1 名司机 (N:1)
9.  **审计异常记录 (History_Log-Exception)**: 多条日志记录关联到具体异常记录的具体记录 (N:1)
10. **审计司机 (History_Log-Driver)**: 多条日志记录关联到具体司机的具体记录 (N:1)


### 1.3 E-R 图

![ER Diagram](E-R图.png)


## 1.4 用户角色与权限

### 用户组织架构图

系统设计了三类用户角色：

```mermaid
graph TD
    UserRoot((系统用户))

    %% 分支1：管理员
    UserRoot --> Admin[系统管理员]
    Admin --> A1[配送中心/车队管理]
    Admin --> A2[全局统计报表]
    Admin --> A3[系统审计日志]

    %% 分支2：调度主管
    UserRoot --> Dispatcher[调度主管]
    Dispatcher --> B1[运单分配调度]
    Dispatcher --> B2[车辆司机状态管理]
    Dispatcher --> B3[本车队异常处理]

    %% 分支3：司机
    UserRoot --> Driver[司机]
    Driver --> C1[查询我的运单]
    Driver --> C2[更新运输状态]
    Driver --> C3[异常问题上报]

    style Admin fill:#f9f,stroke:#333,stroke-width:2px
    style Dispatcher fill:#bbf,stroke:#333,stroke-width:2px
    style Driver fill:#dfd,stroke:#333,stroke-width:2px
```

### 系统功能模块图

```mermaid
graph TD
    %% 根节点
    System[智慧物流车队与配送管理系统]

    %% 第一层：功能模块分类
    System --> AdminMod[管理员功能模块]
    System --> DispMod[调度主管功能模块]
    System --> DriverMod[司机端功能模块]

    %% 第二层：管理员具体功能
    AdminMod --> A1[配送中心监控]
    AdminMod --> A2[全局数据看板]
    AdminMod --> A3[统计报表查询]
    AdminMod --> A4[审计日志审查]

    %% 第二层：调度主管具体功能
    DispMod --> B1[车队资源总览]
    DispMod --> B2[运单分配调度]
    DispMod --> B3[司机车辆管理]
    DispMod --> B4[异常记录处理]

    %% 第二层：司机具体功能
    DriverMod --> C1[我的任务运单]
    DriverMod --> C2[运输状态更新]
    DriverMod --> C3[突发异常上报]

    %% 样式定义 (仿照示例图风格)
    style System fill:#fff,stroke:#333
    
    style AdminMod fill:#fff,stroke:#333,stroke-width:2px
    style DispMod fill:#fff,stroke:#333,stroke-width:2px
    style DriverMod fill:#fff,stroke:#333,stroke-width:2px
    
    style A1 fill:#fff,stroke:#333
    style A2 fill:#fff,stroke:#333
    style A3 fill:#fff,stroke:#333
    style A4 fill:#fff,stroke:#333
    
    style B1 fill:#fff,stroke:#333
    style B2 fill:#fff,stroke:#333
    style B3 fill:#fff,stroke:#333
    style B4 fill:#fff,stroke:#333
    
    style C1 fill:#fff,stroke:#333
    style C2 fill:#fff,stroke:#333
    style C3 fill:#fff,stroke:#333
```


## 2. 逻辑结构设计

### 2.1 关系模式

将上述 E-R 图转换为关系模式，下划线表示主键，双下划线表示外键。

1.  **Distribution_Center** (<u>center_id</u>, center_name, address)
2.  **Fleet** (<u>fleet_id</u>, fleet_name, <span style="text-decoration: underline double;">center_id</span>)
3.  **Dispatcher** (<u>dispatcher_id</u>, name, password, <span style="text-decoration: underline double;">fleet_id</span>)
4.  **Vehicle** (<u>plate_number</u>, <span style="text-decoration: underline double;">fleet_id</span>, max_weight, max_volume, status)
5.  **Driver** (<u>driver_id</u>, name, license_level, phone, <span style="text-decoration: underline double;">fleet_id</span>)
6.  **Order** (<u>Order_id</u>, cargo_weight, cargo_volume, destination, status, <span style="text-decoration: underline double;">vehicle_plate</span>, <span style="text-decoration: underline double;">driver_id</span>, start_time, end_time)
7.  **Exception_Record** (<u>record_id</u>, <span style="text-decoration: underline double;">vehicle_plate</span>, <span style="text-decoration: underline double;">driver_id</span>, occur_time, exception_type, specific_event, fine_amount, handle_status, description)
8.  **History_Log** (<u>log_id</u>, table_name, record_key, column_name, old_value, new_value, change_time, operator)

### 2.2 规范化分析

各个关系模式的函数依赖集如下：

1.  **配送中心表 (Distribution_Center)**
    $$
    F = \left\{
    \begin{aligned}
    \text{center\_id} \to \text{center\_name}, \text{address}
    \end{aligned}
    \right\}
    $$

2.  **车队表 (Fleet)**
    $$
    F = \left\{
    \begin{aligned}
    \text{fleet\_id} \to \text{fleet\_name}, \text{center\_id}
    \end{aligned}
    \right\}
    $$

3.  **调度主管表 (Dispatcher)**
    $$
    F = \left\{
    \begin{aligned}
    \text{dispatcher\_id} \to \text{name}, \text{password}, \text{fleet\_id}
    \end{aligned}
    \right\}
    $$

4.  **车辆表 (Vehicle)**
    $$
    F = \left\{
    \begin{aligned}
    \text{plate\_number} \to \text{fleet\_id}, \text{max\_weight}, \text{max\_volume}, \text{status}
    \end{aligned}
    \right\}
    $$

5.  **司机表 (Driver)**
    $$
    F = \left\{
    \begin{aligned}
    \text{driver\_id} \to \text{name}, \text{license\_level}, \text{phone}, \text{fleet\_id}
    \end{aligned}
    \right\}
    $$

6.  **运单表 (Order)**
    $$
    F = \left\{
    \begin{aligned}
    \text{Order\_id} \to \text{cargo\_weight}, \text{cargo\_volume}, \text{destination}, \text{status}, \\
    \text{start\_time}, \text{end\_time}, \text{vehicle\_plate}, \text{driver\_id}
    \end{aligned}
    \right\}
    $$

7.  **异常记录表 (Exception_Record)**
    $$
    F = \left\{
    \begin{aligned}
    \text{record\_id} \to \text{vehicle\_plate}, \text{driver\_id}, \text{occur\_time}, \text{exception\_type}, \\
    \text{specific\_event}, \text{fine\_amount}, \text{handle\_status}, \text{description}
    \end{aligned}
    \right\}
    $$

8.  **审计日志表 (History_Log)**
    $$
    F = \left\{
    \begin{aligned}
    \text{log\_id} \to \text{table\_name}, \text{record\_key}, \text{column\_name}, \text{old\_value}, \\
    \text{new\_value}, \text{change\_time}, \text{operator}
    \end{aligned}
    \right\}
    $$

可以看到上述所有设计关系模式均具有唯一的候选键（即主键）。每一个非平凡函数依赖的左部都包含了候选键，所有非主属性完全依赖于主键，且不存在非主属性对码的传递依赖。因此，**所有关系模式均符合 3NF 及 BCNF 设计规范**，有效消除了数据冗余和潜在的更新异常


## 3. 物理结构与高级对象设计

### 3.1 表结构定义

首先在SSMS中创建数据库 `FleetDistributionDB`，并使用以下 SQL 脚本创建各个表结构，定义主键、外键及完整性约束：

```sql
-- 1. Distribution_Center (center_id, center_name, address)
CREATE TABLE Distribution_Center (
    center_id INT IDENTITY(1,1) PRIMARY KEY, -- 中心编号
    center_name NVARCHAR(50) NOT NULL,       -- 中心名称
    address NVARCHAR(100)                    -- 地址
);
GO
```
```sql
-- 2. Fleet (fleet_id, fleet_name, center_id)
CREATE TABLE Fleet (
    fleet_id INT IDENTITY(1,1) PRIMARY KEY, -- 车队编号
    fleet_name NVARCHAR(50) NOT NULL,       -- 车队名称
    center_id INT NOT NULL,                 -- 所属中心
    CONSTRAINT FK_Fleet_Center FOREIGN KEY (center_id) REFERENCES Distribution_Center(center_id)
);
GO
```
```sql
-- 3. Dispatcher (dispatcher_id, name, password, fleet_id)
CREATE TABLE Dispatcher (
    dispatcher_id NVARCHAR(20) PRIMARY KEY, -- 主管工号
    name NVARCHAR(50) NOT NULL,             -- 姓名
    password NVARCHAR(50) NOT NULL,         -- 密码
    fleet_id INT NOT NULL UNIQUE,           -- 所属车队 (1:1 关系)
    CONSTRAINT FK_Dispatcher_Fleet FOREIGN KEY (fleet_id) REFERENCES Fleet(fleet_id)
);
GO
```
```sql
-- 4. Vehicle (plate_number, fleet_id, max_weight, max_volume, status)
CREATE TABLE Vehicle (
    plate_number NVARCHAR(20) PRIMARY KEY,      -- 车牌号
    fleet_id INT NOT NULL,                      -- 所属车队
    max_weight DECIMAL(10, 2) NOT NULL,         -- 最大载重
    max_volume DECIMAL(10, 2) NOT NULL,         -- 最大容积
    status NVARCHAR(20) NOT NULL DEFAULT 'Idle',-- 车辆状态
    -- 状态约束：空闲、运输中、维修中、异常 以及外键
    CONSTRAINT CK_Vehicle_Status CHECK (status IN ('Idle', 'Busy', 'Maintenance', 'Exception')),
    CONSTRAINT FK_Vehicle_Fleet FOREIGN KEY (fleet_id) REFERENCES Fleet(fleet_id)
);
GO
```
```sql
-- 5. Driver (driver_id, name, license_level, phone, fleet_id)
CREATE TABLE Driver (
    driver_id NVARCHAR(20) PRIMARY KEY,  -- 司机工号
    name NVARCHAR(50) NOT NULL,          -- 姓名
    password NVARCHAR(50) NOT NULL DEFAULT '123456', -- 密码 
    license_level NVARCHAR(10) NOT NULL, -- 驾照等级
    phone NVARCHAR(20),                  -- 电话
    fleet_id INT NOT NULL,               -- 所属车队
    CONSTRAINT FK_Driver_Fleet FOREIGN KEY (fleet_id) REFERENCES Fleet(fleet_id)
);
GO
```
```sql
-- 6. Order (Order_id, cargo_weight, cargo_volume, destination, 
--          status, vehicle_plate, driver_id, start_time, end_time)
CREATE TABLE [Order] (
    Order_id NVARCHAR(20) PRIMARY KEY,    -- 运单号
    cargo_weight DECIMAL(10, 2) NOT NULL, -- 货物重量
    cargo_volume DECIMAL(10, 2) NOT NULL, -- 货物体积
    destination NVARCHAR(100) NOT NULL,   -- 目的地
    status NVARCHAR(20) NOT NULL DEFAULT 'Pending', -- 运单状态
    vehicle_plate NVARCHAR(20),           -- 承运车辆
    driver_id NVARCHAR(20),               -- 承运司机
    start_time DATETIME,                  -- 发车时间
    end_time DATETIME,                    -- 签收时间
    -- 完整性约束以及外键
    CONSTRAINT CK_Order_Status CHECK (status IN ('Pending', 'Loading', 'In-Transit', 'Delivered')),
    CONSTRAINT FK_Order_Vehicle FOREIGN KEY (vehicle_plate) REFERENCES Vehicle(plate_number),
    CONSTRAINT FK_Order_Driver FOREIGN KEY (driver_id) REFERENCES Driver(driver_id)
);
GO
```
```sql
-- 7. Exception_Record (record_id, vehicle_plate, driver_id, occur_time, 
--          exception_type, specific_event, fine_amount, handle_status, description)
CREATE TABLE Exception_Record (
    record_id BIGINT IDENTITY(1,1) PRIMARY KEY,   -- 记录ID
    vehicle_plate NVARCHAR(20),                   -- 涉事车辆
    driver_id NVARCHAR(20),                       -- 涉事司机
    occur_time DATETIME DEFAULT GETDATE(),        -- 发生时间
    exception_type NVARCHAR(20) NOT NULL,         -- 异常类型
    specific_event NVARCHAR(50),                  -- 具体事件
    fine_amount DECIMAL(10, 2) DEFAULT 0,         -- 罚款金额
    handle_status NVARCHAR(20) DEFAULT 'Unprocessed', -- 处理状态
    description NVARCHAR(200),                    -- 描述
    -- 完整性约束以及外键
    CONSTRAINT CK_Exception_Type CHECK (exception_type IN ('Transit_Exception', 'Idle_Exception')),
    CONSTRAINT CK_Handle_Status CHECK (handle_status IN ('Unprocessed', 'Processed')),
    CONSTRAINT FK_Exception_Vehicle FOREIGN KEY (vehicle_plate) REFERENCES Vehicle(plate_number),
    CONSTRAINT FK_Exception_Driver FOREIGN KEY (driver_id) REFERENCES Driver(driver_id)
);
GO
```
```sql
-- 8. History_Log (log_id, table_name, record_key, column_name, old_value, new_value, change_time, operator)
CREATE TABLE History_Log (
    log_id BIGINT IDENTITY(1,1) PRIMARY KEY, -- 日志ID
    table_name NVARCHAR(50) NOT NULL,        -- 表名
    record_key NVARCHAR(50) NOT NULL,        -- 记录主键值
    column_name NVARCHAR(50) NOT NULL,       -- 变更字段名
    old_value NVARCHAR(MAX),                 -- 旧值
    new_value NVARCHAR(MAX),                 -- 新值
    change_time DATETIME DEFAULT GETDATE(),  -- 变更时间
    operator NVARCHAR(50)                    -- 操作人
);
GO
```

### 3.2 触发器设计
为了实现业务自动化和数据完整性，我们实现了 6 个触发器来完成实验任务中的要求：

1.  **自动载重校验**
    **TRG_Load_Check**
    设计意图以及逻辑：
    该触发器 `TRG_Load_Check` 负责在运单通过 `Order` 表分配或更新前，强制执行安全与一致性校验。它通过 INSTEAD OF 的方式拦截非法操作，确保，车辆必须处于 `Idle` 状态添加货物，不向其他状态的车辆分配运单，同时司机与车辆归属，且不会导致超载或超容。
    代码如下，详细的实现逻辑见注释：
    ```sql
    -- TRG_Load_Check
    CREATE TRIGGER TRG_Load_Check
    ON [Order]
    AFTER INSERT, UPDATE -- 触发时机：INSERT, UPDATE (适配运单分配或信息变更)
    AS
    BEGIN
        SET NOCOUNT ON;
        -- 仅在车辆分配或货物信息变更时进行校验
        IF NOT (UPDATE(vehicle_plate) OR UPDATE(driver_id) OR UPDATE(cargo_weight) OR UPDATE(cargo_volume))
            RETURN;
        DECLARE @VehiclePlate NVARCHAR(20);
        DECLARE @DriverID NVARCHAR(20);
        DECLARE @MaxWeight DECIMAL(10, 2);
        DECLARE @MaxVolume DECIMAL(10, 2);
        DECLARE @CurrentWeight DECIMAL(10, 2);
        DECLARE @CurrentVolume DECIMAL(10, 2);
        DECLARE @VehicleFleetID INT;
        DECLARE @DriverFleetID INT;
        DECLARE @VehicleStatus NVARCHAR(20);
        SELECT TOP 1 
            @VehiclePlate = vehicle_plate, 
            @DriverID = driver_id
        FROM inserted
        WHERE vehicle_plate IS NOT NULL; -- 只校验已分配车辆的记录

        IF @VehiclePlate IS NULL RETURN;
        -- 状态校验: 只允许分配 Idle (空闲) 的车辆
        SELECT @VehicleStatus = status FROM Vehicle WHERE plate_number = @VehiclePlate;
        
        IF @VehicleStatus IN ('Busy', 'Exception', 'Maintenance')
        BEGIN
            RAISERROR ('错误：无法分配运单。车辆当前状态非空闲 (Busy/Exception/Maintenance)。', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END
        -- 车队一致性校验
        IF @DriverID IS NOT NULL
        BEGIN
            SELECT @VehicleFleetID = fleet_id FROM Vehicle WHERE plate_number = @VehiclePlate;
            SELECT @DriverFleetID = fleet_id FROM Driver WHERE driver_id = @DriverID;
            IF @VehicleFleetID <> @DriverFleetID
            BEGIN
                RAISERROR ('错误：司机与车辆必须属于同一车队。', 16, 1);
                ROLLBACK TRANSACTION;
                RETURN;
            END
        END
        -- 载重与容积校验
        SELECT 
            @MaxWeight = max_weight, 
            @MaxVolume = max_volume 
        FROM Vehicle 
        WHERE plate_number = @VehiclePlate;
        SELECT 
            @CurrentWeight = ISNULL(SUM(cargo_weight), 0),
            @CurrentVolume = ISNULL(SUM(cargo_volume), 0)
        FROM [Order]
        WHERE vehicle_plate = @VehiclePlate 
        AND status IN ('Pending', 'Loading', 'In-Transit');

        IF (@CurrentWeight > @MaxWeight)
        BEGIN
            RAISERROR ('错误：车辆超载！(当前总重超过最大载重)', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF (@CurrentVolume > @MaxVolume)
        BEGIN
            RAISERROR ('错误：车辆容积不足！', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END
    END;
    GO
    ```

2.  **车辆状态自动流转**
    **TRG_Auto_Status_Update**
    设计意图以及逻辑：
    该触发器 `TRG_Auto_Status_Update` 负责车辆状态的自动化闭环管理。它实现了两个核心逻辑：一是“发车即锁定”，当运单状态更新为 `In-Transit` 时，自动将空闲车辆锁定为 `Busy`，防止重复派单；二是“完单即释放”，当运单送达（`Delivered`）后，自动检查车辆是否清空了所有任务，若无残留运单则立即恢复 `Idle` 状态。
    代码如下，详细的实现逻辑见注释：
    ```sql
    -- TRG_Auto_Status_Update
    CREATE TRIGGER TRG_Auto_Status_Update
    ON [Order]
    AFTER UPDATE
    AS
    BEGIN
        SET NOCOUNT ON;
        IF NOT UPDATE(status) RETURN;

        -- 场景 1: 运单状态变更为 In-Transit (运输中) -> 车辆变为 Busy
        UPDATE v
        SET v.status = 'Busy'
        FROM Vehicle v
        JOIN inserted i ON v.plate_number = i.vehicle_plate
        WHERE i.status = 'In-Transit' AND v.status = 'Idle';

        -- 场景 2: 运单状态变更为 Delivered (已送达) -> 检查是否释放车辆
        DECLARE @VehiclePlate NVARCHAR(20);
        DECLARE @ActiveOrdersCount INT;

        DECLARE cur CURSOR FOR
        SELECT DISTINCT i.vehicle_plate
        FROM inserted i
        JOIN deleted d ON i.Order_id = d.Order_id
        WHERE i.status = 'Delivered' AND d.status <> 'Delivered' AND i.vehicle_plate IS NOT NULL;
        OPEN cur;
        FETCH NEXT FROM cur INTO @VehiclePlate;
        
        WHILE @@FETCH_STATUS = 0
        BEGIN
            -- 检查该车辆是否还有未完成的运单 (Pending, Loading, In-Transit)
            SELECT @ActiveOrdersCount = COUNT(*)
            FROM [Order]
            WHERE vehicle_plate = @VehiclePlate 
            AND status IN ('Pending', 'Loading', 'In-Transit');

            -- 如果没有活跃运单，且车辆当前是 Busy (或 Loading)，则恢复为 Idle
            IF @ActiveOrdersCount = 0
            BEGIN
                UPDATE Vehicle
                SET status = 'Idle'
                WHERE plate_number = @VehiclePlate 
                AND status IN ('Busy');
            END
            FETCH NEXT FROM cur INTO @VehiclePlate;
        END
        CLOSE cur;
        DEALLOCATE cur;
    END;
    GO
    ```

    **TRG_Exception_Flag**
    设计意图以及逻辑：
    该触发器 `TRG_Exception_Flag` 实现了异常状态的即时响应。一旦系统或人工在 `Exception_Record` 表中录入新的异常，触发器立即将关联车辆的状态强制置为 `Exception`。这能确保在车辆发生故障或事故的毫秒级时间内阻断新的任务分配。
    代码如下，详细的实现逻辑见注释：
    ```sql
    -- TRG_Exception_Flag
    CREATE TRIGGER TRG_Exception_Flag
    ON Exception_Record
    AFTER INSERT
    AS
    BEGIN
        SET NOCOUNT ON;
        UPDATE v
        SET v.status = 'Exception'
        FROM Vehicle v
        JOIN inserted i ON v.plate_number = i.vehicle_plate
        WHERE i.vehicle_plate IS NOT NULL;
    END;
    GO
    ```

    **TRG_Exception_Recovery**
    设计意图以及逻辑：
    该触发器 `TRG_Exception_Recovery` 负责异常解除后的状态智能路由。当异常处理状态更新为 `Processed` 时，它不会盲目地将车辆重置为空闲，而是检查该车是否身负未完成的运单。若仍有任务，恢复为 `Busy` 继续运输；若无任务，才恢复为 `Idle` 待命。
    代码如下，详细的实现逻辑见注释：
    ```sql
    -- TRG_Exception_Recovery
    CREATE TRIGGER TRG_Exception_Recovery
    ON Exception_Record
    AFTER UPDATE
    AS
    BEGIN
        SET NOCOUNT ON;
        -- 只关注处理状态变更
        IF NOT UPDATE(handle_status) RETURN;

        DECLARE @VehiclePlate NVARCHAR(20);
        DECLARE @UnprocessedCount INT;
        DECLARE @ActiveOrdersCount INT;

        DECLARE cur CURSOR FOR
        SELECT DISTINCT i.vehicle_plate
        FROM inserted i
        WHERE i.handle_status = 'Processed' AND i.vehicle_plate IS NOT NULL;
        OPEN cur;
        FETCH NEXT FROM cur INTO @VehiclePlate;
        
        WHILE @@FETCH_STATUS = 0
        BEGIN
            -- 检查该车是否还有未处理的异常
            SELECT @UnprocessedCount = COUNT(*)
            FROM Exception_Record
            WHERE vehicle_plate = @VehiclePlate AND handle_status = 'Unprocessed';

            IF @UnprocessedCount = 0
            BEGIN
                -- 既然没有异常了，判断应该恢复成什么状态
                SELECT @ActiveOrdersCount = COUNT(*)
                FROM [Order]
                WHERE vehicle_plate = @VehiclePlate AND status IN ('Pending', 'Loading', 'In-Transit');

                IF @ActiveOrdersCount > 0
                    UPDATE Vehicle SET status = 'Busy' WHERE plate_number = @VehiclePlate;
                ELSE
                    UPDATE Vehicle SET status = 'Idle' WHERE plate_number = @VehiclePlate;
            END
            FETCH NEXT FROM cur INTO @VehiclePlate;
        END
        CLOSE cur;
        DEALLOCATE cur;
    END;
    GO
    ```

3.  **审计日志**
    **TRG_Driver_Update_Audit**
    设计意图以及逻辑：
    该触发器 `TRG_Driver_Update_Audit` 用于维护司机核心资质数据的可追溯性。它监听 `Driver` 表的更新操作，一旦发现驾照等级（`license_level`）或联系电话（`phone`）发生变更，自动抓取旧值与新值，并记录操作人，确保证照信息的每一次变动都有据可查。
    代码如下，详细的实现逻辑见注释：
    ```sql
    -- TRG_Driver_Update_Audit
    CREATE TRIGGER TRG_Driver_Update_Audit
    ON Driver
    AFTER UPDATE
    AS
    BEGIN
        SET NOCOUNT ON;
        DECLARE @Operator NVARCHAR(50);
        -- 从CONTEXT_INFO读取操作人，如果没有设置则使用System_Trigger
        SELECT @Operator = ISNULL(CAST(CONTEXT_INFO() AS NVARCHAR(50)), 'System_Trigger');
        IF @Operator = '' SET @Operator = 'System_Trigger';

        -- 监控 license_level 变更
        INSERT INTO History_Log (table_name, record_key, column_name, old_value, new_value, operator)
        SELECT 
            'Driver', i.driver_id, 'license_level', d.license_level, i.license_level, @Operator
        FROM inserted i
        JOIN deleted d ON i.driver_id = d.driver_id
        WHERE i.license_level <> d.license_level;

        -- 监控 phone 变更
        INSERT INTO History_Log (table_name, record_key, column_name, old_value, new_value, operator)
        SELECT 
            'Driver', i.driver_id, 'phone', ISNULL(d.phone, 'NULL'), ISNULL(i.phone, 'NULL'), @Operator
        FROM inserted i
        JOIN deleted d ON i.driver_id = d.driver_id
        WHERE ISNULL(i.phone, '') <> ISNULL(d.phone, '');
    END;
    GO
    ```

    **TRG_Exception_Audit**
    设计意图以及逻辑：
    该触发器 `TRG_Exception_Audit` 专注于异常处理流程的合规审计。当 `Exception_Record` 表的处理状态（`handle_status`）发生流转时，系统自动捕捉这一关键动作，记录状态变更的历史轨迹，为后续的责任认定提供不可篡改的数据支持。
    代码如下，详细的实现逻辑见注释：
    ```sql
    -- TRG_Exception_Audit
    CREATE TRIGGER TRG_Exception_Audit
    ON Exception_Record
    AFTER UPDATE
    AS
    BEGIN
        SET NOCOUNT ON;
        DECLARE @Operator NVARCHAR(50);
        SELECT @Operator = ISNULL(CAST(CONTEXT_INFO() AS NVARCHAR(50)), 'System_Trigger');
        IF @Operator = '' SET @Operator = 'System_Trigger';

        INSERT INTO History_Log (table_name, record_key, column_name, old_value, new_value, operator)
        SELECT 
            'Exception_Record', CAST(i.record_id AS NVARCHAR(50)), 'handle_status', d.handle_status, i.handle_status, @Operator
        FROM inserted i
        JOIN deleted d ON i.record_id = d.record_id
        WHERE i.handle_status <> d.handle_status;
    END;
    GO
    ```

### 3.3 核心业务逻辑封装：存储过程 (Stored Procedures)

为了提高系统性能并保证业务逻辑的一致性，本项目将复杂的聚合计算与多步骤查询封装为存储过程。这种设计有效减少了应用层与数据库之间的网络交互（Round-trips），并将统计口径严格收敛于数据库层。

#### 3.3.1 车队月度运营报表 (`SP_Calc_Fleet_Monthly_Report`)

该过程用于生成指定车队的月度运营汇总报表。过程以 `@ReportDate` 计算当月的时间区间（采用 `[Start, End)` 的左闭右开方式避免跨月边界误差），并在数据库侧一次性完成统计口径的收敛：包括该车队当月运单总数、异常总数与罚款总额，从而减少应用层多次查询带来的网络往返与口径不一致问题。

```sql
-- 计算指定车队、月份的总运单数、异常数、罚款总额
CREATE PROCEDURE SP_Calc_Fleet_Monthly_Report
    @FleetID INT,
    @ReportDate DATE -- 传入日期，取该日期的年份和月份
AS
BEGIN
    DECLARE @StartDate DATETIME;
    DECLARE @EndDate DATETIME;
    -- 计算该月的第一天和下个月的第一天
    SET @StartDate = DATEFROMPARTS(YEAR(@ReportDate), MONTH(@ReportDate), 1);
    SET @EndDate = DATEADD(MONTH, 1, @StartDate);
    SELECT  -- 结果集
        f.fleet_name,
        FORMAT(@StartDate, 'yyyy-MM') AS report_month,
        -- 统计该车队关联车辆的运单总数 (根据 start_time 统计)
        (SELECT COUNT(*) 
         FROM [Order] o 
         JOIN Vehicle v ON o.vehicle_plate = v.plate_number
         WHERE v.fleet_id = @FleetID 
           AND o.start_time >= @StartDate AND o.start_time < @EndDate) AS total_orders,
        -- 统计该车队关联车辆/司机的异常总数
        (SELECT COUNT(*)
         FROM Exception_Record ex
         JOIN Vehicle v ON ex.vehicle_plate = v.plate_number
         WHERE v.fleet_id = @FleetID
           AND ex.occur_time >= @StartDate AND ex.occur_time < @EndDate) AS total_exceptions,
        -- 统计总罚款
        (SELECT ISNULL(SUM(fine_amount), 0)
         FROM Exception_Record ex
         JOIN Vehicle v ON ex.vehicle_plate = v.plate_number
         WHERE v.fleet_id = @FleetID
           AND ex.occur_time >= @StartDate AND ex.occur_time < @EndDate) AS total_fine_amount
    FROM Fleet f
    WHERE f.fleet_id = @FleetID;
END;
GO
```


#### 3.3.2 司机绩效与异常透视 (`SP_Get_Driver_Performance`)

该过程面向“司机详情页”的查询需求，一次调用即可返回两类信息：首先给出司机在指定时间段内的完单数（以 `Delivered` 运单数量作为绩效指标），随后返回该司机对应的异常记录明细（按时间倒序，包含异常类型、罚款与处理状态），以减少前端拆分查询造成的多次往返。

```sql
-- 查询指定司机在特定时间段内的绩效（完成单数）及异常明细
CREATE PROCEDURE SP_Get_Driver_Performance
    @DriverID NVARCHAR(20),
    @StartDate DATETIME,
    @EndDate DATETIME
AS
BEGIN
    SET NOCOUNT ON;
    -- 返回概要信息
    SELECT 
        d.name,
        d.driver_id,
        (SELECT COUNT(*) 
         FROM [Order] 
         WHERE driver_id = @DriverID 
           AND status = 'Delivered'
           AND end_time BETWEEN @StartDate AND @EndDate) AS completed_orders_count
    FROM Driver d
    WHERE d.driver_id = @DriverID;
    -- 返回异常明细列表
    SELECT 
        record_id,
        occur_time,
        exception_type,
        specific_event,
        fine_amount,
        handle_status,
        [description]
    FROM Exception_Record
    WHERE driver_id = @DriverID
      AND occur_time BETWEEN @StartDate AND @EndDate
    ORDER BY occur_time DESC;
END;
GO
```

### 3.4 数据抽象与展示优化：视图 (Views)

视图层作为物理表与应用层之间的缓冲接口，用于固化高频的联表查询逻辑（Joins）并简化数据结构，使前端开发无需关注底层复杂的实体关系（ER）模型。

#### 3.4.1 实时异常预警看板

我们设计该视图用于系统首页的异常预警看板，以便直接拉取最近一周内的异常数据流，帮助调度与管理人员快速发现高优问题并进行处置。设计逻辑：以 `Exception_Record` 为主表，通过时间条件 `DATEADD(DAY, -7, GETDATE())` 限定窗口，并使用 `LEFT JOIN` 将车辆、司机与车队信息联表补全，保证即使关联数据缺失也能保留异常记录本身。

```sql
USE FleetDistributionDB;
GO
-- 展示最近 7 天发生过异常的车辆和司机，供仪表盘调用
CREATE VIEW VW_Weekly_Alert AS
SELECT 
    er.record_id,
    er.occur_time,
    er.exception_type,
    er.specific_event,
    er.handle_status,
    v.plate_number,
    d.driver_id,
    d.name AS driver_name,
    f.fleet_name
FROM Exception_Record er
LEFT JOIN Vehicle v ON er.vehicle_plate = v.plate_number
LEFT JOIN Driver d ON er.driver_id = d.driver_id
LEFT JOIN Fleet f ON v.fleet_id = f.fleet_id
WHERE er.occur_time >= DATEADD(DAY, -7, GETDATE());
GO
```

#### 3.4.2 配送中心资源全景图 

我们设计该视图用于给区域调度员提供“按配送中心查看资源”的统一入口，避免前端每次查询都要重复处理跨层级的多表关联。设计逻辑：通过三联表 `Distribution_Center -> Fleet -> Vehicle` 将中心、车队与车辆串联成一张宽表，并用 `CASE` 将车辆状态映射为业务可读的可用性标签（`Available/Unavailable`）。

该视图将分散的物理表聚合为统一的逻辑视图，如下图所示：

```mermaid
graph LR
    subgraph Physical_Tables [物理表层]
        DC[Distribution_Center]
        Fleet[Fleet]
        Veh[Vehicle]
    end

    subgraph Logic_View [逻辑视图层]
        View[VW_Center_Resource_Status]
    end

    DC -->|JOIN center_id| Fleet
    Fleet -->|JOIN fleet_id| Veh
    Veh -->|Projection & Calculation| View

    %% 样式定义
    style View fill:#fff9c4,stroke:#fbc02d,stroke-width:2px
    style Physical_Tables fill:#e1f5fe,stroke:#01579b,stroke-dasharray: 5 5
```

```sql
-- 联表查询 Vehicle-Fleet-Distribution_Center，方便按配送中心层级查看车辆状态
IF OBJECT_ID('VW_Center_Resource_Status', 'V') IS NOT NULL DROP VIEW VW_Center_Resource_Status;
GO

CREATE VIEW VW_Center_Resource_Status AS
SELECT 
    dc.center_id,
    dc.center_name,
    f.fleet_id,
    f.fleet_name,
    v.plate_number,
    v.max_weight,
    v.max_volume,
    v.status AS vehicle_status,
    -- 计算当前车辆是否可以接单 (仅 Idle 状态且无锁定)
    CASE 
        WHEN v.status = 'Idle' THEN 'Available'
        ELSE 'Unavailable'
    END AS availability
FROM Vehicle v
JOIN Fleet f ON v.fleet_id = f.fleet_id
JOIN Distribution_Center dc ON f.center_id = dc.center_id;
GO
```

### 3.5 索引策略 (Indexes)

#### 3.5.1 索引设置策略
我们在设置索引时遵循的思路很简单：先从页面与接口对应的 SQL 入手，找出最常见的 `WHERE` 条件、`JOIN` 连接列以及 `ORDER BY` 排序列，再为这些“高频访问路径”建立非聚集索引，把全表扫描尽量转化为索引查找（Index Seek）或索引范围扫描（Index Range Scan）
对于多条件查询，我们优先采用复合索引，并把选择性更高、过滤更强的列放在前面，保证优化器能利用左前缀原则命中索引。同时，对于一些查询中会频繁访问但不适合作为索引键的列（例如查询结果中需要返回的字段），我们会使用 `INCLUDE` 关键字将其作为覆盖索引的一部分，减少回表操作，提高查询效率。

下面给出本实验中用于创建主要索引：

```sql
-- 1 车辆状态筛选：支持调度模块快速定位空闲车辆
CREATE NONCLUSTERED INDEX IDX_Vehicle_Status ON Vehicle (status) INCLUDE (max_weight, max_volume);
GO
-- 2 运单时间范围：支持按时间窗口拉取运单、生成报表
CREATE NONCLUSTERED INDEX IDX_Order_Date ON [Order] (start_time, end_time);
GO
-- 3 司机绩效（工号 + 完单 + 时间）：支持司机详情页 KPI 查询
CREATE NONCLUSTERED INDEX IDX_Order_Driver_EndTime ON [Order] (driver_id, status, end_time) INCLUDE (Order_id);
GO
-- 4 司机异常明细：支持按工号检索异常并按时间排序
CREATE NONCLUSTERED INDEX IDX_Exception_Driver_OccurTime ON Exception_Record (driver_id, occur_time);
GO
-- 5 运单与车辆关联（触发器/统计常用）：支持按车牌聚合活跃运单的载重/体积
CREATE NONCLUSTERED INDEX IDX_Order_Vehicle ON [Order] (vehicle_plate) INCLUDE (status, cargo_weight, cargo_volume);
GO
```

#### 3.5.2 索引性能对比
我们使用 SQL Server 的执行计划（EXPLAIN）与 `SET STATISTICS IO/TIME` 对同一组查询做对照测试。测试数据规模为 `[Order]` 与 `Exception_Record` 各约 100,000 条（靠模拟），指标主要看逻辑读取，并结合执行计划变化判断是否由全表扫描转为索引查找

具体对比结果如下表所示：

| 查询 | 无索引 Logical Reads | 加索引后 Logical Reads |
| --- | ---: | ---: |
| 运单时间窗口查询 | 2005 | 6 |
| 司机完单统计 | 2005 | 3 |
| 司机异常明细 | 1954 | 62 |
| 待分配运单 | 2005 | 157 |

对应的性能对比图如下所示：

![alt text](index_performance_cn.png)

如图所示，可以看到我们建立索引后，典型高频查询的 I/O 开销显著下降，尤其是运单的时间窗口查询、按司机工号统计绩效以及异常明细检索，这些原本会在大表上产生扫描的 SQL，在建立索引后能够更多地走索引查找/范围扫描，从而提高查询效率，索引对大表的范围过滤与按外键检索提升最明显：运单时间窗口与司机绩效类查询的逻辑读下降到个位数或几十页，异常明细的读取也显著减少


## 4. 系统实现与测试

### 4.1 开发环境
*   操作系统: Windows
*   数据库: Microsoft SQL Server 2019 
*   数据库开发软件: SQL Server Management Studio (SSMS)
*   后端编程语言: Python 3.10
*   Web 应用框架: Django 4.2
*   前端框架: Bootstrap 5

### 4.2 关键功能展示

#### 4.2.1 司机、车辆基础信息录入管理

司机录入功能，可以看到在填好信息之后，点击提交按钮，信息会被存入数据库中，同时也会在左边进行显示
<div>
<center>
<img src="asserts/image-31.png" width="49%"/>
<img src="asserts/image-32.png" width="49%"/>
</center>
</div>

<div>
<center>
<img src="asserts/image-33.png" width="49%"/>
<img src="asserts/image-34.png" width="49%"/>
</center>
</div>

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



### 4.3 前端技术选型与关键代码

本系统定位为“多角色管理后台”，页面以表单提交、表格展示与状态更新为主，交互复杂度不高但对一致的布局与组件复用要求较强。因此我们采用 Django 模板（服务端渲染）作为页面组织方式，并以 Bootstrap 5 提供响应式栅格、表格、表单与 Modal 等通用组件，配合 Font Awesome 图标与少量自定义 CSS 统一视觉风格；需要的动态交互尽量用原生 JavaScript 完成（例如选择运单、高亮提示、弹窗反馈），避免引入完整前端框架带来的工程复杂度。

关键代码如下（节选自项目实际页面与静态资源）：

1）统一布局与多角色导航：通过 `base.html` 进行模板继承，并基于 `request.session.role` 在同一套导航中切换不同角色入口，同时引入 Bootstrap 与自定义样式。

```html
<!DOCTYPE html>
{% load static %}
<html lang="en">
<head>
    <link href="https://maxcdn.bootstrapcdn.com/font-awesome/4.7.0/css/font-awesome.min.css" rel="stylesheet">
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
    <link rel="stylesheet" href="{% static 'managersystem/css/app.css' %}">
</head>
<body>
<nav class="navbar navbar-expand-lg navbar-dark bg-dark mynav">
    {% if request.session.role == "dispatcher" %}
        <a class="nav-link" href="{% url 'order_page' %}">运单分配</a>
        <a class="nav-link" href="{% url 'exception_page' %}">异常管理</a>
    {% endif %}
</nav>
<main class="container my-4 page-animate">
    {% block content %}{% endblock %}
</main>
<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"></script>
{% block extra_js %}{% endblock %}
</body>
</html>
```

2）操作结果的统一反馈：在运单分配页中，我们使用 Bootstrap Modal 承载 Django `messages` 的提示信息，页面加载后自动弹窗，让“成功/错误/警告”的反馈更集中且不打断布局。

```html
<div class="modal fade" id="messageModal" tabindex="-1" aria-hidden="true">
  <div class="modal-dialog modal-dialog-centered">
    <div class="modal-content">
      <div class="modal-header" id="modalHeader">
        <h5 class="modal-title" id="modalTitle">提示</h5>
        <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
      </div>
      <div class="modal-body" id="modalBody"></div>
    </div>
  </div>
</div>

<script>
document.addEventListener('DOMContentLoaded', function() {
  {% if messages %}{% for message in messages %}
    showMessageModal('{{ message.message|escapejs }}', '{{ message.tags }}');
  {% endfor %}{% endif %}
});

function showMessageModal(messageText, messageType) {
  const modal = new bootstrap.Modal(document.getElementById('messageModal'));
  const modalHeader = document.getElementById('modalHeader');
  const modalTitle = document.getElementById('modalTitle');
  const modalBody = document.getElementById('modalBody');
  modalHeader.className = 'modal-header';
  if (messageType.includes('error') || messageType.includes('danger')) {
    modalHeader.classList.add('bg-danger', 'text-white');
    modalTitle.textContent = '错误';
  } else if (messageType.includes('success')) {
    modalHeader.classList.add('bg-success', 'text-white');
    modalTitle.textContent = '成功';
  }
  modalBody.textContent = messageText;
  modal.show();
}
</script>
```

3）视觉一致性：自定义 `app.css` 对背景、卡片、按钮等进行统一风格处理，保证管理后台在不同页面之间的观感一致。

```css
body {
    font-family: "Montserrat", "Segoe UI", system-ui, -apple-system, sans-serif;
    background-image: url("../images/background.jpg");
    background-size: cover;
    background-attachment: fixed;
}

.card {
    background: rgba(255, 255, 255, 0.9);
    border-radius: 12px;
    box-shadow: 0 12px 30px rgba(15, 23, 42, 0.08);
}
```

同时，为了让“表单提交 + 列表展示 + 状态更新”这类后台页面逻辑更集中、权限边界更清晰，我们将主要业务流程收敛在 Django 的 `views.py` 中完成：包括多角色鉴权拦截、登录后会话写入（role、fleet_id、user_name）、首页统计数据准备、运单状态更新的原子事务控制、异常记录的处理与创建，以及报表页通过存储过程保证统计口径一致。相关关键实现代码如下：

1）角色鉴权与统一入口：将权限控制前置，避免模板层到处做身份判断。

```python
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
    return redirect("dispatcher_login")
```

2）登录与会话写入：登录成功后写入角色、车队与用户名，后续页面无需重复查用户基础信息。

```python
def dispatcher_login(request):
    if request.method == "POST":
        dispatcher_id = request.POST.get("dispatcher_id", "").strip()
        password = request.POST.get("password", "").strip()
        user = authenticate(request, username=dispatcher_id, password=password, role="dispatcher")
        if user is not None:
            auth_login(request, user)
            dispatcher = Dispatcher.objects.get(dispatcher_id=dispatcher_id)
            request.session["role"] = "dispatcher"  # 写入角色
            request.session["fleet_id"] = dispatcher.fleet_id  # 绑定车队
            request.session["user_name"] = dispatcher.name
            messages.success(request, "登录成功。")
            return redirect("dashboard")
        messages.error(request, "账号或密码错误。")
    return render(request, "managersystem/login_dispatcher.html")
```

3）首页统计与视图数据准备：在 View 层聚合统计数据，模板只负责渲染。

```python
status_summary = {key: 0 for key in VEHICLE_STATUS_LABELS}
for row in vehicle_queryset.values("status").annotate(total=Count("status")):
    status_summary[row["status"]] = row["total"]

stats = {
    "total_vehicles": sum(status_summary.values()),
    "total_drivers": driver_queryset.count(),
    "pending_orders": Order.objects.filter(status="Pending").count(),
    "unprocessed_exceptions": exception_queryset.filter(handle_status="Unprocessed").count(),
}
```

4）运单分配与状态更新（事务控制）：通过原子事务确保状态更新与完成时间写入一致。

```python
if action == "update_status":
    order_id = request.POST.get("order_id")
    new_status = request.POST.get("new_status")
    with transaction.atomic():
        order = Order.objects.get(order_id=order_id)
        order.status = new_status
        if new_status == "Delivered":
            order.end_time = timezone.now()
        order.save()
    messages.success(request, f"运单 {order_id} 状态已更新。")
```

5）异常管理：统一入口处理“标记已处理”和“新增异常”，并给出明确反馈。

```python
if action == "resolve":
    record = ExceptionRecord.objects.get(record_id=record_id)
    if record.handle_status == "Unprocessed":
        record.handle_status = "Processed"
        record.save()
        messages.success(request, f"异常记录 {record_id} 已处理。")

ExceptionRecord.objects.create(
    vehicle_plate_id=vehicle_plate,
    driver_id=driver_id,
    exception_type=exception_type,
    fine_amount=fine_amount or 0,
    handle_status="Unprocessed",
)
```

6）报表查询：在 View 层直接调用数据库存储过程，保证统计口径统一。

```python
with connection.cursor() as cursor:
    cursor.execute("EXEC SP_Calc_Fleet_Monthly_Report %s, %s", [fleet_id, full_date])
    columns = [col[0] for col in cursor.description]
    fleet_report = [dict(zip(columns, row)) for row in cursor.fetchall()]
```



### 4.4 核心技术难点与解决方案

我设计过程中我们觉得最难攻克的难点就是：基于触发器的复杂业务逻辑实现，主要体现在以下两个方面：

#### 4.4.1 多条件下的车辆状态机自动流转

我们遇到的难点是：车辆状态（Idle / Busy / Exception）并不是“随一张运单线性变化”的。运单发车时确实需要立刻锁定车辆为 Busy，但在批量签收或同车多单的场景下，单个运单 Delivered 并不代表车辆就空闲；如果简单做“完单即回 Idle”，会把仍在执行其他运单的车辆错误释放，导致后续调度与统计全部偏离。

我们的解决方案是把状态机逻辑下沉到触发器 `TRG_Auto_Status_Update`：当 `Order` 进入 In-Transit 时触发器将车辆置 Busy，并加上 `WHERE v.status = 'Idle'` 的防御判断避免覆盖更高优先级的 Exception；当 `Order` 进入 Delivered 时不直接回写 Idle，而是基于 `inserted` 中涉及到的车辆逐一检查其“活跃运单计数”（仍处于 Pending/Loading/In-Transit 的记录是否存在），仅当计数为 0 才恢复为 Idle，从而保证同车多单、批量更新下每辆车状态都能被正确计算。

#### 4.4.2 异常处理的闭环恢复逻辑

我们在异常闭环上遇到的具体难点是“恢复状态不唯一”：异常一旦发生需要立即阻断调度并强制锁车，但当某条异常被处理为 Processed 时，车辆可能仍有其他未处理异常（仍应保持 Exception），也可能需要继续完成未送达运单（应恢复 Busy），或者所有任务已结束（应恢复 Idle）。如果恢复逻辑写在应用层，很容易因为并发或漏判导致状态错乱。

我们的解决方案采用两段触发器联动：`TRG_Exception_Flag` 负责即时熔断，只要 `Exception_Record` 新增记录就把车辆状态统一置为 Exception，确保受损车辆不会被继续调度；`TRG_Exception_Recovery` 负责“恢复判定”，在异常被标记为 Processed 后先检查该车是否仍存在 `handle_status='Unprocessed'` 的异常记录，若存在则继续维持 Exception；若异常已清零，再检查是否还有进行中的运单（Pending/Loading/In-Transit），有则恢复 Busy，无则恢复 Idle，从而把异常处理后的状态恢复做成可验证、可追溯的闭环。


## 5. 总结

## 5.1 实践心得

通过学习数据库系统原理并完成本次“智能物流车队与配送管理系统”的课程设计，我们把课堂中学习到的关于关系模型、范式理论、SQL 语句的编写、事务一致性与性能优化的知识串成了一条完整链路：从需求抽象出实体与关系，到用规范化的表结构承载业务，再到用触发器、视图和存储过程把关键规则落到数据库层，最后结合 Django 的 Web 框架实现多角色的管理后台与业务闭环。相比单纯写 SQL 语句编程，这次项目涵盖了本学习在理论和实验课上学习到的全部的内容，让我们更直观深刻地理解数据库在一致性、可维护性和性能上的功能和价值

在实现过程中，我们一方面用 3NF 思路对配送中心、车队、车辆、司机、运单、异常与审计等模块进行拆分建模，用主键/外键/检查约束明确边界；另一方面把容易出错、且需要强一致的规则（如分配时的载重与车队一致性校验、车辆状态机自动流转、异常熔断与恢复、关键字段变更审计）通过触发器固化到数据层，让系统在并发或异常操作下仍能保持稳定，在应用方面，我们通过 Django 的 Web 框架把登录与会话、角色权限分离、事务更新与反馈提示组织起来，配合 Bootstrap 模板实现了较为清晰的后台交互与页面结构，从而完成了一个较为完整的数据库应用系统

在完成本次的大作业，我们也对我们设计的系统进行了反思和回顾，既有优点，同时也还有很多需要完善的地方：

优点：
- 能围绕业务流程把数据库设计做完整（表结构、约束、触发器、视图/存储过程都有对应场景）
- 能用“先规则、后功能”的思路把关键校验下沉到数据库，减少应用层反复判断带来的不一致
- 前后端组织相对清晰，多角色界面与操作路径比较明确，页面交互与业务规则能对应起来

不足：
- 对复杂触发器的边界情况覆盖不够系统，更多依赖手工测试，缺少可复现的测试脚本与数据集
- 对安全与权限的考虑还偏“功能可用”，更细粒度的权限控制、异常输入校验与审计字段完善仍有提升空间
- 前端交互仍较为基础，缺少更丰富的动态反馈与用户体验设计，未来可以考虑引入更现代的前端框架进行改进
- 同时功能上仍有较多可扩展空间，我们还可以增加更加丰富的功能，比如在地图上标记我们的配送中心以及显示配送路线，增加对绩效考核与奖励机制的功能和数据等等

### 5.2 数据库效率优化的思考与总结

通过本次实验我对于数据库效率优化有了更加深刻的理解和认识：数据库它提供了一些传统文件系统/本地存储不具备的能力，比如视图、索引、触发器等等强大和特殊的功能，这些功能会直接减少重复计算、降低 I/O、收敛口径并提升并发一致性，从而使得我们的系统和应用更加的高效和可靠：
数据库可以使用视图，把高频的多表关联与筛选固化成可复用的查询入口，让应用层不需要每次都拼接复杂 SQL，也减少了因不同页面/不同人写法不一致导致的“口径漂移”。在本系统中，视图承担了“告警/汇总/统计展示”这类读取密集型需求，相当于把复杂 JOIN 路径提前组织好，使前端页面只做简单 SELECT 即可获取结果。
数据库可以使用触发器，把关键规则与状态机下沉到数据库写入路径上，做到“写入即校验、写入即联动”，这是本地存储很难保证的一致性能力。在本系统中，`TRG_Load_Check` 把车辆状态、车队一致性、载重/容积等校验集中在数据层并在违规时回滚，避免应用层多处校验与并发下的漏判；`TRG_Auto_Status_Update`、`TRG_Exception_Flag`、`TRG_Exception_Recovery` 则把车辆状态机与异常闭环做成自动化联动，减少人工维护状态带来的额外操作与错误修复成本。
数据库可以使用索引，文件系统/本地存储往往只能“全量遍历 + 应用层过滤”，而关系数据库可以通过索引与优化器把查询从全表扫描变为定位/范围扫描，从而显著降低逻辑读与响应时间。我们在高频 WHERE/JOIN/ORDER BY 字段上建立索引，并用 `SET STATISTICS IO, TIME` 与执行计划验证效果，把性能提升落到可量化的数据对比上。
数据库可以使用事务来对进行并发控制，数据库能提供原子性与一致性语义，让一组更新要么全部成功、要么全部回滚，并通过主键/外键/检查约束在数据层兜底。这类能力在本地存储中往往需要额外实现锁、日志、回滚与校验框架，复杂且容易出错。对我们来说，把约束与事务交给数据库，可以减少应用层的“补丁式校验”，也让并发场景下的数据正确性更可控。
最后总的来说，通过本次实验我深刻体会到数据库系统在效率优化上的重要作用：它不仅仅是一个数据存储的容器，更是一个强大的数据处理引擎，能够通过视图、触发器、索引与事务等机制提升系统的整体性能与一致性

最后的最后，本学期的数据库实验就到这里结束了，回顾整个学期的学习和实践，我觉得收获颇丰，不仅掌握了数据库设计与实现的基本技能，也深刻体会到了数据库系统的强大功能和理解，希望未来能将所学知识应用到更多实际项目中，能够学以致用，最后感谢老师耐心指导，也由衷的感谢助教老师辛苦付出和指导！

## 6. 附录

### 6.1 主要 SQL 脚本
**表格建立**
```sql
USE FleetDistributionDB;
GO

-- 1. Distribution_Center (center_id, center_name, address)
IF OBJECT_ID('Distribution_Center', 'U') IS NOT NULL DROP TABLE Distribution_Center;
CREATE TABLE Distribution_Center (
    center_id INT IDENTITY(1,1) PRIMARY KEY, -- 中心编号
    center_name NVARCHAR(50) NOT NULL,       -- 中心名称
    address NVARCHAR(100)                    -- 地址
);
GO

-- 2. Fleet (fleet_id, fleet_name, center_id)
IF OBJECT_ID('Fleet', 'U') IS NOT NULL DROP TABLE Fleet;
CREATE TABLE Fleet (
    fleet_id INT IDENTITY(1,1) PRIMARY KEY, -- 车队编号
    fleet_name NVARCHAR(50) NOT NULL,       -- 车队名称
    center_id INT NOT NULL,                 -- 所属中心
    CONSTRAINT FK_Fleet_Center FOREIGN KEY (center_id) REFERENCES Distribution_Center(center_id)
);
GO

-- 3. Dispatcher (dispatcher_id, name, password, fleet_id)
IF OBJECT_ID('Dispatcher', 'U') IS NOT NULL DROP TABLE Dispatcher;
CREATE TABLE Dispatcher (
    dispatcher_id NVARCHAR(20) PRIMARY KEY, -- 主管工号
    name NVARCHAR(50) NOT NULL,             -- 姓名
    password NVARCHAR(50) NOT NULL,         -- 密码
    fleet_id INT NOT NULL UNIQUE,           -- 所属车队 (1:1 关系)
    CONSTRAINT FK_Dispatcher_Fleet FOREIGN KEY (fleet_id) REFERENCES Fleet(fleet_id)
);
GO

-- 4. Vehicle (plate_number, fleet_id, max_weight, max_volume, status)
IF OBJECT_ID('Vehicle', 'U') IS NOT NULL DROP TABLE Vehicle;
CREATE TABLE Vehicle (
    plate_number NVARCHAR(20) PRIMARY KEY,      -- 车牌号
    fleet_id INT NOT NULL,                      -- 所属车队
    max_weight DECIMAL(10, 2) NOT NULL,         -- 最大载重
    max_volume DECIMAL(10, 2) NOT NULL,         -- 最大容积
    status NVARCHAR(20) NOT NULL DEFAULT 'Idle',-- 车辆状态
    
    -- 状态约束：空闲、运输中、维修中、异常 以及外键
    CONSTRAINT CK_Vehicle_Status CHECK (status IN ('Idle', 'Busy', 'Maintenance', 'Exception')),
    CONSTRAINT FK_Vehicle_Fleet FOREIGN KEY (fleet_id) REFERENCES Fleet(fleet_id)
);
GO

-- 5. Driver (driver_id, name, license_level, phone, fleet_id)
IF OBJECT_ID('Driver', 'U') IS NOT NULL DROP TABLE Driver;
CREATE TABLE Driver (
    driver_id NVARCHAR(20) PRIMARY KEY,  -- 司机工号
    name NVARCHAR(50) NOT NULL,          -- 姓名
    password NVARCHAR(50) NOT NULL DEFAULT '123456', -- 密码 
    license_level NVARCHAR(10) NOT NULL, -- 驾照等级
    phone NVARCHAR(20),                  -- 电话
    fleet_id INT NOT NULL,               -- 所属车队
    CONSTRAINT FK_Driver_Fleet FOREIGN KEY (fleet_id) REFERENCES Fleet(fleet_id)
);
GO

-- 6. Order (Order_id, cargo_weight, cargo_volume, destination, 
--          status, vehicle_plate, driver_id, start_time, end_time)
IF OBJECT_ID('[Order]', 'U') IS NOT NULL DROP TABLE [Order];
CREATE TABLE [Order] (
    Order_id NVARCHAR(20) PRIMARY KEY,    -- 运单号
    cargo_weight DECIMAL(10, 2) NOT NULL, -- 货物重量
    cargo_volume DECIMAL(10, 2) NOT NULL, -- 货物体积
    destination NVARCHAR(100) NOT NULL,   -- 目的地
    status NVARCHAR(20) NOT NULL DEFAULT 'Pending', -- 运单状态
    vehicle_plate NVARCHAR(20),           -- 承运车辆
    driver_id NVARCHAR(20),               -- 承运司机
    start_time DATETIME,                  -- 发车时间
    end_time DATETIME,                    -- 签收时间

    -- 完整性约束以及外键
    CONSTRAINT CK_Order_Status CHECK (status IN ('Pending', 'Loading', 'In-Transit', 'Delivered')),
    CONSTRAINT FK_Order_Vehicle FOREIGN KEY (vehicle_plate) REFERENCES Vehicle(plate_number),
    CONSTRAINT FK_Order_Driver FOREIGN KEY (driver_id) REFERENCES Driver(driver_id)
);
GO

-- 7. Exception_Record (record_id, vehicle_plate, driver_id, occur_time, 
--          exception_type, specific_event, fine_amount, handle_status, description)
IF OBJECT_ID('Exception_Record', 'U') IS NOT NULL DROP TABLE Exception_Record;
CREATE TABLE Exception_Record (
    record_id BIGINT IDENTITY(1,1) PRIMARY KEY,   -- 记录ID
    vehicle_plate NVARCHAR(20),                   -- 涉事车辆
    driver_id NVARCHAR(20),                       -- 涉事司机
    occur_time DATETIME DEFAULT GETDATE(),        -- 发生时间
    exception_type NVARCHAR(20) NOT NULL,         -- 异常类型
    specific_event NVARCHAR(50),                  -- 具体事件
    fine_amount DECIMAL(10, 2) DEFAULT 0,         -- 罚款金额
    handle_status NVARCHAR(20) DEFAULT 'Unprocessed', -- 处理状态
    description NVARCHAR(200),                    -- 描述

    -- 完整性约束以及外键
    CONSTRAINT CK_Exception_Type CHECK (exception_type IN ('Transit_Exception', 'Idle_Exception')),
    CONSTRAINT CK_Handle_Status CHECK (handle_status IN ('Unprocessed', 'Processed')),
    CONSTRAINT FK_Exception_Vehicle FOREIGN KEY (vehicle_plate) REFERENCES Vehicle(plate_number),
    CONSTRAINT FK_Exception_Driver FOREIGN KEY (driver_id) REFERENCES Driver(driver_id)
);
GO

-- 8. History_Log (log_id, table_name, record_key, column_name, old_value, new_value, change_time, operator)
IF OBJECT_ID('History_Log', 'U') IS NOT NULL DROP TABLE History_Log;
CREATE TABLE History_Log (
    log_id BIGINT IDENTITY(1,1) PRIMARY KEY, -- 日志ID
    table_name NVARCHAR(50) NOT NULL,        -- 表名
    record_key NVARCHAR(50) NOT NULL,        -- 记录主键值
    column_name NVARCHAR(50) NOT NULL,       -- 变更字段名
    old_value NVARCHAR(MAX),                 -- 旧值
    new_value NVARCHAR(MAX),                 -- 新值
    change_time DATETIME DEFAULT GETDATE(),  -- 变更时间
    operator NVARCHAR(50)                    -- 操作人
);
GO

```

**触发器**
```sql
USE FleetDistributionDB;
GO

-- 1. TRG_Load_Check (安全校验 & 状态校验)
IF OBJECT_ID('TRG_Load_Check', 'TR') IS NOT NULL DROP TRIGGER TRG_Load_Check;
GO

CREATE TRIGGER TRG_Load_Check
ON [Order]
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- 仅在车辆分配或货物信息变更时进行校验
    IF NOT (UPDATE(vehicle_plate) OR UPDATE(driver_id) OR UPDATE(cargo_weight) OR UPDATE(cargo_volume))
        RETURN;

    DECLARE @VehiclePlate NVARCHAR(20);
    DECLARE @DriverID NVARCHAR(20);
    DECLARE @MaxWeight DECIMAL(10, 2);
    DECLARE @MaxVolume DECIMAL(10, 2);
    DECLARE @CurrentWeight DECIMAL(10, 2);
    DECLARE @CurrentVolume DECIMAL(10, 2);
    DECLARE @VehicleFleetID INT;
    DECLARE @DriverFleetID INT;
    DECLARE @VehicleStatus NVARCHAR(20);

    -- 选取涉及车辆的任意一条记录进行检查
    SELECT TOP 1 
        @VehiclePlate = vehicle_plate, 
        @DriverID = driver_id
    FROM inserted
    WHERE vehicle_plate IS NOT NULL; -- 只校验已分配车辆的记录

    IF @VehiclePlate IS NULL RETURN;

    -- A. 状态校验: 只允许分配 Idle (空闲) 的车辆
    SELECT @VehicleStatus = status FROM Vehicle WHERE plate_number = @VehiclePlate;
    
    IF @VehicleStatus IN ('Busy', 'Exception', 'Maintenance')
    BEGIN
        RAISERROR ('错误：无法分配运单。车辆当前状态非空闲 (Busy/Exception/Maintenance)。', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END

    -- B. 车队一致性校验
    IF @DriverID IS NOT NULL
    BEGIN
        SELECT @VehicleFleetID = fleet_id FROM Vehicle WHERE plate_number = @VehiclePlate;
        SELECT @DriverFleetID = fleet_id FROM Driver WHERE driver_id = @DriverID;

        IF @VehicleFleetID <> @DriverFleetID
        BEGIN
            RAISERROR ('错误：司机与车辆必须属于同一车队。', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END
    END

    -- C. 载重与容积校验
    SELECT 
        @MaxWeight = max_weight, 
        @MaxVolume = max_volume 
    FROM Vehicle 
    WHERE plate_number = @VehiclePlate;

    -- 计算该车辆当前所有未完成运单的总重/总体积 (状态不为 Delivered)
    SELECT 
        @CurrentWeight = ISNULL(SUM(cargo_weight), 0),
        @CurrentVolume = ISNULL(SUM(cargo_volume), 0)
    FROM [Order]
    WHERE vehicle_plate = @VehiclePlate 
      AND status IN ('Pending', 'Loading', 'In-Transit');

    IF (@CurrentWeight > @MaxWeight)
    BEGIN
        RAISERROR ('错误：车辆超载！(当前总重超过最大载重)', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END

    IF (@CurrentVolume > @MaxVolume)
    BEGIN
        RAISERROR ('错误：车辆容积不足！', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
END;
GO


-- 2. TRG_Auto_Status_Update (车辆状态自动流转)

IF OBJECT_ID('TRG_Auto_Status_Update', 'TR') IS NOT NULL DROP TRIGGER TRG_Auto_Status_Update;
GO

CREATE TRIGGER TRG_Auto_Status_Update
ON [Order]
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT UPDATE(status) RETURN;

    -- 场景 1: 运单状态变更为 In-Transit (运输中) -> 车辆变为 Busy
    -- 只有当车辆当前是 Idle 时才更新，避免覆盖 Exception 等状态
    UPDATE v
    SET v.status = 'Busy'
    FROM Vehicle v
    JOIN inserted i ON v.plate_number = i.vehicle_plate
    WHERE i.status = 'In-Transit'
      AND v.status = 'Idle';

    -- 场景 2: 运单状态变更为 Delivered (已送达) -> 检查是否释放车辆
    DECLARE @VehiclePlate NVARCHAR(20);
    DECLARE @ActiveOrdersCount INT;

    -- 遍历所有状态变为 Delivered 的车辆
    DECLARE cur CURSOR FOR
    SELECT DISTINCT i.vehicle_plate
    FROM inserted i
    JOIN deleted d ON i.Order_id = d.Order_id
    WHERE i.status = 'Delivered' AND d.status <> 'Delivered' AND i.vehicle_plate IS NOT NULL;

    OPEN cur;
    FETCH NEXT FROM cur INTO @VehiclePlate;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- 检查该车辆是否还有未完成的运单 (Pending, Loading, In-Transit)
        SELECT @ActiveOrdersCount = COUNT()
        FROM [Order]
        WHERE vehicle_plate = @VehiclePlate 
          AND status IN ('Pending', 'Loading', 'In-Transit');

        -- 如果没有活跃运单，且车辆当前是 Busy (或 Loading)，则恢复为 Idle
        IF @ActiveOrdersCount = 0
        BEGIN
            UPDATE Vehicle
            SET status = 'Idle'
            WHERE plate_number = @VehiclePlate 
              AND status IN ('Busy');
        END

        FETCH NEXT FROM cur INTO @VehiclePlate;
    END

    CLOSE cur;
    DEALLOCATE cur;
END;
GO


-- 3. TRG_Exception_Flag (异常标记)

IF OBJECT_ID('TRG_Exception_Flag', 'TR') IS NOT NULL DROP TRIGGER TRG_Exception_Flag;
GO

CREATE TRIGGER TRG_Exception_Flag
ON Exception_Record
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE v
    SET v.status = 'Exception'
    FROM Vehicle v
    JOIN inserted i ON v.plate_number = i.vehicle_plate
    WHERE i.vehicle_plate IS NOT NULL;
END;
GO


-- 4. TRG_Exception_Recovery (智能恢复)
IF OBJECT_ID('TRG_Exception_Recovery', 'TR') IS NOT NULL DROP TRIGGER TRG_Exception_Recovery;
GO

CREATE TRIGGER TRG_Exception_Recovery
ON Exception_Record
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    -- 只关注处理状态变更
    IF NOT UPDATE(handle_status) RETURN;

    DECLARE @VehiclePlate NVARCHAR(20);
    DECLARE @UnprocessedCount INT;
    DECLARE @ActiveOrdersCount INT;

    DECLARE cur CURSOR FOR
    SELECT DISTINCT i.vehicle_plate
    FROM inserted i
    WHERE i.handle_status = 'Processed' AND i.vehicle_plate IS NOT NULL;

    OPEN cur;
    FETCH NEXT FROM cur INTO @VehiclePlate;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- 检查该车是否还有未处理的异常
        SELECT @UnprocessedCount = COUNT(*)
        FROM Exception_Record
        WHERE vehicle_plate = @VehiclePlate AND handle_status = 'Unprocessed';

        IF @UnprocessedCount = 0
        BEGIN
            -- 既然没有异常了，判断应该恢复成什么状态
            SELECT @ActiveOrdersCount = COUNT(*)
            FROM [Order]
            WHERE vehicle_plate = @VehiclePlate AND status IN ('Pending', 'Loading', 'In-Transit');

            IF @ActiveOrdersCount > 0
                UPDATE Vehicle SET status = 'Busy' WHERE plate_number = @VehiclePlate;
            ELSE
                UPDATE Vehicle SET status = 'Idle' WHERE plate_number = @VehiclePlate;
        END

        FETCH NEXT FROM cur INTO @VehiclePlate;
    END

    CLOSE cur;
    DEALLOCATE cur;
END;
GO

-- 5. TRG_Exception_Audit (异常审计)
IF OBJECT_ID('TRG_Exception_Audit', 'TR') IS NOT NULL DROP TRIGGER TRG_Exception_Audit;
GO

CREATE TRIGGER TRG_Exception_Audit
ON Exception_Record
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Operator NVARCHAR(50);
    -- 从CONTEXT_INFO读取操作人，如果没有设置则使用System_Trigger
    SELECT @Operator = ISNULL(CAST(CONTEXT_INFO() AS NVARCHAR(50)), 'System_Trigger');
    IF @Operator = '' SET @Operator = 'System_Trigger';

    INSERT INTO History_Log (table_name, record_key, column_name, old_value, new_value, operator)
    SELECT 
        'Exception_Record',
        CAST(i.record_id AS NVARCHAR(50)),
        'handle_status',
        d.handle_status,
        i.handle_status,
        @Operator
    FROM inserted i
    JOIN deleted d ON i.record_id = d.record_id
    WHERE i.handle_status <> d.handle_status;
END;
GO


-- 6. TRG_Driver_Update_Audit (司机信息审计)
IF OBJECT_ID('TRG_Driver_Update_Audit', 'TR') IS NOT NULL DROP TRIGGER TRG_Driver_Update_Audit;
GO

CREATE TRIGGER TRG_Driver_Update_Audit
ON Driver
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Operator NVARCHAR(50);
    -- 从CONTEXT_INFO读取操作人，如果没有设置则使用System_Trigger
    SELECT @Operator = ISNULL(CAST(CONTEXT_INFO() AS NVARCHAR(50)), 'System_Trigger');
    IF @Operator = '' SET @Operator = 'System_Trigger';

    -- 监控 license_level 变更
    INSERT INTO History_Log (table_name, record_key, column_name, old_value, new_value, operator)
    SELECT 
        'Driver',
        i.driver_id,
        'license_level',
        d.license_level,
        i.license_level,
        @Operator
    FROM inserted i
    JOIN deleted d ON i.driver_id = d.driver_id
    WHERE i.license_level <> d.license_level;

    -- 监控 phone 变更 (补充关键信息，注意NULL值处理)
    INSERT INTO History_Log (table_name, record_key, column_name, old_value, new_value, operator)
    SELECT 
        'Driver',
        i.driver_id,
        'phone',
        ISNULL(d.phone, 'NULL'),
        ISNULL(i.phone, 'NULL'),
        @Operator
    FROM inserted i
    JOIN deleted d ON i.driver_id = d.driver_id
    WHERE ISNULL(i.phone, '') <> ISNULL(d.phone, '');
END;
GO

```

**存储过程**
```sql
USE FleetDistributionDB;
GO

-- 1. SP_Calc_Fleet_Monthly_Report
-- 计算指定车队、月份的总运单数、异常数、罚款总额
IF OBJECT_ID('SP_Calc_Fleet_Monthly_Report', 'P') IS NOT NULL DROP PROCEDURE SP_Calc_Fleet_Monthly_Report;
GO

CREATE PROCEDURE SP_Calc_Fleet_Monthly_Report
    @FleetID INT,
    @ReportDate DATE -- 传入日期，取该日期的年份和月份
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @StartDate DATETIME;
    DECLARE @EndDate DATETIME;
    
    -- 计算该月的第一天和下个月的第一天
    SET @StartDate = DATEFROMPARTS(YEAR(@ReportDate), MONTH(@ReportDate), 1);
    SET @EndDate = DATEADD(MONTH, 1, @StartDate);

    -- 结果集
    SELECT 
        f.fleet_name,
        FORMAT(@StartDate, 'yyyy-MM') AS report_month,
        
        -- 统计该车队关联车辆的运单总数 (根据 start_time 统计)
        (SELECT COUNT(*) 
         FROM [Order] o 
         JOIN Vehicle v ON o.vehicle_plate = v.plate_number
         WHERE v.fleet_id = @FleetID 
           AND o.start_time >= @StartDate AND o.start_time < @EndDate) AS total_orders,

        -- 统计该车队关联车辆/司机的异常总数
        (SELECT COUNT(*)
         FROM Exception_Record ex
         JOIN Vehicle v ON ex.vehicle_plate = v.plate_number
         WHERE v.fleet_id = @FleetID
           AND ex.occur_time >= @StartDate AND ex.occur_time < @EndDate) AS total_exceptions,

        -- 统计总罚款
        (SELECT ISNULL(SUM(fine_amount), 0)
         FROM Exception_Record ex
         JOIN Vehicle v ON ex.vehicle_plate = v.plate_number
         WHERE v.fleet_id = @FleetID
           AND ex.occur_time >= @StartDate AND ex.occur_time < @EndDate) AS total_fine_amount

    FROM Fleet f
    WHERE f.fleet_id = @FleetID;
END;
GO

-- 2. SP_Get_Driver_Performance
-- 查询指定司机在特定时间段内的绩效（完成单数）及异常明细
IF OBJECT_ID('SP_Get_Driver_Performance', 'P') IS NOT NULL DROP PROCEDURE SP_Get_Driver_Performance;
GO

CREATE PROCEDURE SP_Get_Driver_Performance
    @DriverID NVARCHAR(20),
    @StartDate DATETIME,
    @EndDate DATETIME
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. 返回概要信息
    SELECT 
        d.name,
        d.driver_id,
        (SELECT COUNT(*) 
         FROM [Order] 
         WHERE driver_id = @DriverID 
           AND status = 'Delivered'
           AND end_time BETWEEN @StartDate AND @EndDate) AS completed_orders_count
    FROM Driver d
    WHERE d.driver_id = @DriverID;

    -- 2. 返回异常明细列表
    SELECT 
        record_id,
        occur_time,
        exception_type,
        specific_event,
        fine_amount,
        handle_status,
        [description]
    FROM Exception_Record
    WHERE driver_id = @DriverID
      AND occur_time BETWEEN @StartDate AND @EndDate
    ORDER BY occur_time DESC;
END;
GO
```

### 6.2 演示视频链接
*(视频链接)*
