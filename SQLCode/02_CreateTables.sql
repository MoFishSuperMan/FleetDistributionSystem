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
