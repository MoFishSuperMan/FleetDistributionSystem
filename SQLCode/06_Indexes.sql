USE FleetDistributionDB;
GO

-- =============================================
-- 索引优化策略
-- =============================================

-- 1. 优化“查找空闲车辆”的查询
-- 高频查询条件：WHERE status = 'Idle'
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IDX_Vehicle_Status' AND object_id = OBJECT_ID('Vehicle'))
CREATE NONCLUSTERED INDEX IDX_Vehicle_Status
ON Vehicle (status)
INCLUDE (max_weight, max_volume); -- 包含列，加速资源查询
GO

-- 2. 优化报表的时间范围统计
-- 高频查询条件：WHERE start_time BETWEEN ... AND ...
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IDX_Order_Date' AND object_id = OBJECT_ID('[Order]'))
CREATE NONCLUSTERED INDEX IDX_Order_Date
ON [Order] (start_time, end_time);
GO

-- 3. 优化司机历史异常查询
-- 高频查询条件：WHERE driver_id = ...
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IDX_Exception_Driver' AND object_id = OBJECT_ID('Exception_Record'))
CREATE NONCLUSTERED INDEX IDX_Exception_Driver
ON Exception_Record (driver_id);
GO

-- 4. 优化运单-车辆关联查询
-- 触发器中大量使用 WHERE vehicle_plate = ...
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IDX_Order_Vehicle' AND object_id = OBJECT_ID('[Order]'))
CREATE NONCLUSTERED INDEX IDX_Order_Vehicle
ON [Order] (vehicle_plate)
INCLUDE (status, cargo_weight, cargo_volume); -- 包含列加速 Sum 计算
GO
