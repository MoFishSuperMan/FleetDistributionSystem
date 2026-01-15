USE FleetDistributionDB;
GO

-- =============================================
-- 1. TRG_Load_Check (安全校验)
-- =============================================
-- 逻辑：
-- 1. 校验车辆剩余载重和容积是否足够（累加该车所有未完成运单）。
-- 2. 校验司机与车辆是否属于同一车队。
IF OBJECT_ID('TRG_Load_Check', 'TR') IS NOT NULL DROP TRIGGER TRG_Load_Check;
GO

CREATE TRIGGER TRG_Load_Check
ON [Order]
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @VehiclePlate NVARCHAR(20);
    DECLARE @DriverID NVARCHAR(20);
    DECLARE @NewWeight DECIMAL(10, 2);
    DECLARE @NewVolume DECIMAL(10, 2);
    DECLARE @MaxWeight DECIMAL(10, 2);
    DECLARE @MaxVolume DECIMAL(10, 2);
    DECLARE @CurrentWeight DECIMAL(10, 2);
    DECLARE @CurrentVolume DECIMAL(10, 2);
    DECLARE @VehicleFleetID INT;
    DECLARE @DriverFleetID INT;

    -- 获取插入的记录信息（假设单条插入，如果是批量插入需使用游标或集合操作，这里简化处理单条）
    SELECT TOP 1 
        @VehiclePlate = vehicle_plate, 
        @DriverID = driver_id, 
        @NewWeight = cargo_weight, 
        @NewVolume = cargo_volume
    FROM inserted;

    -- 如果没有分配车辆或司机，则不进行校验（可能是暂存单据）
    IF @VehiclePlate IS NULL OR @DriverID IS NULL RETURN;

    -- 1. 校验司机与车辆是否属于同一车队
    SELECT @VehicleFleetID = fleet_id FROM Vehicle WHERE plate_number = @VehiclePlate;
    SELECT @DriverFleetID = fleet_id FROM Driver WHERE driver_id = @DriverID;

    IF @VehicleFleetID <> @DriverFleetID
    BEGIN
        RAISERROR ('Error: The driver and vehicle do not belong to the same fleet.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END

    -- 2. 校验载重和容积
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
      AND status IN ('Pending', 'Loading', 'In-Transit')
      AND Order_id NOT IN (SELECT Order_id FROM inserted); -- 排除当前插入的单据(如果是After Trigger，数据已在表中)
      -- 注意：如果是AFTER INSERT，数据已经在表中，计算时是否包含自身取决于具体逻辑。
      -- 这里的 CurrentWeight 如果不包含自身，那么 总重 = Current + New。
      -- 如果上面的查询 exclude 了 inserted，那么下面判断就需要加上 @NewWeight
    
    -- 实际上 AFTER INSERT 时，inserted 表的数据已经进到 [Order] 表了。
    -- 所以更准确的做法是直接统计 [Order] 表中该车所有未送达的重量。
    
    SELECT 
        @CurrentWeight = ISNULL(SUM(cargo_weight), 0),
        @CurrentVolume = ISNULL(SUM(cargo_volume), 0)
    FROM [Order]
    WHERE vehicle_plate = @VehiclePlate 
      AND status IN ('Pending', 'Loading', 'In-Transit');

    IF (@CurrentWeight > @MaxWeight)
    BEGIN
        RAISERROR ('Error: Vehicle overload! Max weight exceeded.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END

    IF (@CurrentVolume > @MaxVolume)
    BEGIN
        RAISERROR ('Error: Vehicle volume exceeded!', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
END;
GO

-- =============================================
-- 2. TRG_Auto_Status_Update (状态流转)
-- =============================================
-- 逻辑：当运单状态变为 Delivered，检查车辆是否不再有正在进行的运单。若是，自动将车辆状态置为 Idle。
IF OBJECT_ID('TRG_Auto_Status_Update', 'TR') IS NOT NULL DROP TRIGGER TRG_Auto_Status_Update;
GO

CREATE TRIGGER TRG_Auto_Status_Update
ON [Order]
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- 只关注状态更新为 Delivered 的记录
    IF NOT UPDATE(status) RETURN;

    DECLARE @VehiclePlate NVARCHAR(20);
    DECLARE @ActiveOrdersCount INT;

    -- 遍历所有状态变为 Delivered 的运单涉及的车辆
    DECLARE cur CURSOR FOR
    SELECT DISTINCT i.vehicle_plate
    FROM inserted i
    JOIN deleted d ON i.Order_id = d.Order_id
    WHERE i.status = 'Delivered' AND d.status <> 'Delivered' AND i.vehicle_plate IS NOT NULL;

    OPEN cur;
    FETCH NEXT FROM cur INTO @VehiclePlate;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- 检查该车辆是否还有未完成的运单
        SELECT @ActiveOrdersCount = COUNT(*)
        FROM [Order]
        WHERE vehicle_plate = @VehiclePlate 
          AND status IN ('Pending', 'Loading', 'In-Transit');

        -- 如果没有活跃运单，且车辆当前不在异常或维修状态，则设为 Idle
        IF @ActiveOrdersCount = 0
        BEGIN
            UPDATE Vehicle
            SET status = 'Idle'
            WHERE plate_number = @VehiclePlate 
              AND status IN ('Busy', 'Loading'); -- 这里假设 Busy 对应 In-Transit/Busy
        END

        FETCH NEXT FROM cur INTO @VehiclePlate;
    END

    CLOSE cur;
    DEALLOCATE cur;
END;
GO

-- =============================================
-- 3. TRG_Exception_Flag (异常标记)
-- =============================================
-- 逻辑：一旦录入异常，立即将关联车辆状态锁定为 Exception。
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

-- =============================================
-- 4. TRG_Exception_Recovery (智能恢复)
-- =============================================
-- 逻辑：当异常记录更新为 Processed，检查车辆是否所有异常都处理完毕。
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

-- =============================================
-- 5. TRG_Exception_Audit (异常审计)
-- =============================================
-- 逻辑：当处理状态变更时，向 History_Log 插入审计记录。
IF OBJECT_ID('TRG_Exception_Audit', 'TR') IS NOT NULL DROP TRIGGER TRG_Exception_Audit;
GO

CREATE TRIGGER TRG_Exception_Audit
ON Exception_Record
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO History_Log (table_name, record_key, column_name, old_value, new_value, operator)
    SELECT 
        'Exception_Record',
        CAST(i.record_id AS NVARCHAR(50)),
        'handle_status',
        d.handle_status,
        i.handle_status,
        'System_Trigger'
    FROM inserted i
    JOIN deleted d ON i.record_id = d.record_id
    WHERE i.handle_status <> d.handle_status;
END;
GO

-- =============================================
-- 6. TRG_Driver_Update_Audit (司机信息审计)
-- =============================================
-- 逻辑：监控驾照等级等关键信息变更，记录旧值到 History_Log。
IF OBJECT_ID('TRG_Driver_Update_Audit', 'TR') IS NOT NULL DROP TRIGGER TRG_Driver_Update_Audit;
GO

CREATE TRIGGER TRG_Driver_Update_Audit
ON Driver
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- 监控 license_level 变更
    INSERT INTO History_Log (table_name, record_key, column_name, old_value, new_value, operator)
    SELECT 
        'Driver',
        i.driver_id,
        'license_level',
        d.license_level,
        i.license_level,
        'System_Trigger'
    FROM inserted i
    JOIN deleted d ON i.driver_id = d.driver_id
    WHERE i.license_level <> d.license_level;
END;
GO
