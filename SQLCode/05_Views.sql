USE FleetDistributionDB;
GO

-- =============================================
-- 1. VW_Weekly_Alert (本周异常警报)
-- 展示最近 7 天发生过异常的车辆和司机，供仪表盘调用
-- =============================================
IF OBJECT_ID('VW_Weekly_Alert', 'V') IS NOT NULL DROP VIEW VW_Weekly_Alert;
GO

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

-- =============================================
-- 2. VW_Center_Resource_Status (资源汇总)
-- 联表查询 Vehicle-Fleet-Distribution_Center，方便按配送中心层级查看车辆状态
-- =============================================
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
