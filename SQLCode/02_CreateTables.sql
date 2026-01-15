USE FleetDistributionDB;
GO

-- =============================================
-- 根据 Frame.md 第 2.1 节关系模式 (Relational Schemas) 创建表结构
-- =============================================

-- 1. Distribution_Center (center_id, center_name, address)
IF OBJECT_ID('Distribution_Center', 'U') IS NOT NULL DROP TABLE Distribution_Center;
CREATE TABLE Distribution_Center (
    center_id INT IDENTITY(1,1) PRIMARY KEY,
    center_name NVARCHAR(50) NOT NULL,
    address NVARCHAR(100)
);
GO

-- 2. Fleet (fleet_id, fleet_name, center_id)
IF OBJECT_ID('Fleet', 'U') IS NOT NULL DROP TABLE Fleet;
CREATE TABLE Fleet (
    fleet_id INT IDENTITY(1,1) PRIMARY KEY,
    fleet_name NVARCHAR(50) NOT NULL,
    center_id INT NOT NULL,
    CONSTRAINT FK_Fleet_Center FOREIGN KEY (center_id) REFERENCES Distribution_Center(center_id)
);
GO

-- 3. Dispatcher (dispatcher_id, name, password, fleet_id)
IF OBJECT_ID('Dispatcher', 'U') IS NOT NULL DROP TABLE Dispatcher;
CREATE TABLE Dispatcher (
    dispatcher_id NVARCHAR(20) PRIMARY KEY,
    name NVARCHAR(50) NOT NULL,
    password NVARCHAR(50) NOT NULL,
    fleet_id INT NOT NULL UNIQUE,  -- 1:1 关系
    CONSTRAINT FK_Dispatcher_Fleet FOREIGN KEY (fleet_id) REFERENCES Fleet(fleet_id)
);
GO

-- 4. Vehicle (plate_number, fleet_id, max_weight, max_volume, status)
IF OBJECT_ID('Vehicle', 'U') IS NOT NULL DROP TABLE Vehicle;
CREATE TABLE Vehicle (
    plate_number NVARCHAR(20) PRIMARY KEY,
    fleet_id INT NOT NULL,
    max_weight DECIMAL(10, 2) NOT NULL,
    max_volume DECIMAL(10, 2) NOT NULL,
    status NVARCHAR(20) NOT NULL DEFAULT 'Idle',
    
    -- 状态约束依据 condition.txt
    CONSTRAINT CK_Vehicle_Status CHECK (status IN ('Idle', 'Loading', 'Busy', 'Maintenance', 'Exception')),
    CONSTRAINT FK_Vehicle_Fleet FOREIGN KEY (fleet_id) REFERENCES Fleet(fleet_id)
);
GO

-- 5. Driver (driver_id, name, license_level, phone, fleet_id)
IF OBJECT_ID('Driver', 'U') IS NOT NULL DROP TABLE Driver;
CREATE TABLE Driver (
    driver_id NVARCHAR(20) PRIMARY KEY,
    name NVARCHAR(50) NOT NULL,
    license_level NVARCHAR(10) NOT NULL,
    phone NVARCHAR(20),
    fleet_id INT NOT NULL,
    CONSTRAINT FK_Driver_Fleet FOREIGN KEY (fleet_id) REFERENCES Fleet(fleet_id)
);
GO

-- 6. Order (Order_id, cargo_weight, cargo_volume, destination, status, vehicle_plate, driver_id, start_time, end_time)
IF OBJECT_ID('[Order]', 'U') IS NOT NULL DROP TABLE [Order];
CREATE TABLE [Order] (
    Order_id NVARCHAR(20) PRIMARY KEY,
    cargo_weight DECIMAL(10, 2) NOT NULL,
    cargo_volume DECIMAL(10, 2) NOT NULL,
    destination NVARCHAR(100) NOT NULL,
    status NVARCHAR(20) NOT NULL DEFAULT 'Pending',
    vehicle_plate NVARCHAR(20),  -- 承运车辆
    driver_id NVARCHAR(20),      -- 承运司机
    start_time DATETIME,
    end_time DATETIME,

    -- 状态约束依据 condition.txt
    CONSTRAINT CK_Order_Status CHECK (status IN ('Pending', 'Loading', 'In-Transit', 'Delivered')),
    CONSTRAINT FK_Order_Vehicle FOREIGN KEY (vehicle_plate) REFERENCES Vehicle(plate_number),
    CONSTRAINT FK_Order_Driver FOREIGN KEY (driver_id) REFERENCES Driver(driver_id)
);
GO

-- 7. Exception_Record (record_id, vehicle_plate, driver_id, occur_time, exception_type, specific_event, fine_amount, handle_status, description)
IF OBJECT_ID('Exception_Record', 'U') IS NOT NULL DROP TABLE Exception_Record;
CREATE TABLE Exception_Record (
    record_id BIGINT IDENTITY(1,1) PRIMARY KEY,
    vehicle_plate NVARCHAR(20),
    driver_id NVARCHAR(20),
    occur_time DATETIME DEFAULT GETDATE(),
    exception_type NVARCHAR(20) NOT NULL,
    specific_event NVARCHAR(50),
    fine_amount DECIMAL(10, 2) DEFAULT 0,
    handle_status NVARCHAR(20) DEFAULT 'Unprocessed',
    description NVARCHAR(200),

    -- 类型与状态约束依据 condition.txt
    CONSTRAINT CK_Exception_Type CHECK (exception_type IN ('Transit_Exception', 'Idle_Exception')),
    CONSTRAINT CK_Handle_Status CHECK (handle_status IN ('Unprocessed', 'Processed')),
    CONSTRAINT FK_Exception_Vehicle FOREIGN KEY (vehicle_plate) REFERENCES Vehicle(plate_number),
    CONSTRAINT FK_Exception_Driver FOREIGN KEY (driver_id) REFERENCES Driver(driver_id)
);
GO

-- 8. History_Log (log_id, table_name, record_key, column_name, old_value, new_value, change_time, operator)
IF OBJECT_ID('History_Log', 'U') IS NOT NULL DROP TABLE History_Log;
CREATE TABLE History_Log (
    log_id BIGINT IDENTITY(1,1) PRIMARY KEY,
    table_name NVARCHAR(50) NOT NULL,
    record_key NVARCHAR(50) NOT NULL,
    column_name NVARCHAR(50) NOT NULL,
    old_value NVARCHAR(MAX),
    new_value NVARCHAR(MAX),
    change_time DATETIME DEFAULT GETDATE(),
    operator NVARCHAR(50)
);
GO
