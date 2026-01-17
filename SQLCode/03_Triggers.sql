USE FleetDistributionDB;
GO

-- =============================================
-- 1. TRG_Load_Check (安全校验 & 状态校验)
-- =============================================
-- 逻辑：
-- 1. 触发时机：INSERT, UPDATE (适配运单分配或信息变更)。
-- 2. 状态校验：仅允许非繁忙状态（Idle）的车辆接受任务；禁止分配给 Busy/Exception/Maintenance 状态的车辆。
-- 3. 容量校验：动态计算车辆当前剩余载重与容积（未完成运单累加），防止超载。
-- 4. 车队校验：确保分配的司机与车辆属于同一车队。
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

    -- 简化处理：假设单次操作涉及同一车辆（通常 UI 操作是单条 update）
    -- 选取涉及车辆的任意一条记录进行检查
    SELECT TOP 1 
        @VehiclePlate = vehicle_plate, 
        @DriverID = driver_id
    FROM inserted
    WHERE vehicle_plate IS NOT NULL; -- 只校验已分配车辆的记录

    IF @VehiclePlate IS NULL RETURN;

    -- A. 状态校验: 只允许分配 Idle (空闲) 的车辆
    -- 注意：如果车辆当前是 Idle，但已经有 Loading 状态的运单，我们仍然认为是 Idle 阶段（装货中），允许继续配载。
    -- 一旦车辆变成 Busy (已发车/运输中)，则禁止再分配。
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
    -- 注意：AFTER TRIGGER，inserted 中的数据已存在于表中，直接 SUM 即可
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

-- =============================================
-- 2. TRG_Auto_Status_Update (车辆状态自动流转)
-- =============================================
-- 逻辑：
-- 1. 发车自动锁定：当运单状态更新为 'In-Transit' (运输中) 时，若车辆为空闲状态，自动变更为 'Busy' (繁忙)。
-- 2. 完单自动释放：当运单状态更新为 'Delivered' (已送达) 时，检查车辆是否不再有未完成的活跃运单。若无，则自动恢复为 'Idle' (空闲)。
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
        SELECT @ActiveOrdersCount = COUNT(*)
        FROM [Order]
        WHERE vehicle_plate = @VehiclePlate 
          AND status IN ('Pending', 'Loading', 'In-Transit');

        -- 如果没有活跃运单，且车辆当前是 Busy (或 Loading)，则恢复为 Idle
        -- 注意不覆盖 Exception/Maintenance
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
