USE FleetDistributionDB;
GO

-- =============================================
-- 索引前后性能对比 (SQL Server)
-- 说明：
-- 1) 先在“未建索引”环境执行本脚本，记录执行计划/IO/耗时。
-- 2) 执行 SQLCode/06_Indexes.sql 创建索引。
-- 3) 再次执行本脚本，对比差异。
--
-- 方式 A：查看执行计划 (类似 EXPLAIN)
-- 方式 B：查看 IO/TIME 统计
-- =============================================

-- 可选：若要模拟“无索引”环境，可临时删除索引（测试完请恢复）
-- DROP INDEX IDX_Vehicle_Status ON Vehicle;
-- DROP INDEX IDX_Vehicle_Fleet_Status ON Vehicle;
-- DROP INDEX IDX_Order_Date ON [Order];
-- DROP INDEX IDX_Order_Vehicle ON [Order];
-- DROP INDEX IDX_Order_Driver_EndTime ON [Order];
-- DROP INDEX IDX_Order_Driver_StartTime ON [Order];
-- DROP INDEX IDX_Order_Status_OrderId ON [Order];
-- DROP INDEX IDX_Exception_Driver ON Exception_Record;
-- DROP INDEX IDX_Exception_Driver_OccurTime ON Exception_Record;
-- DROP INDEX IDX_Exception_Vehicle_HandleStatus ON Exception_Record;
-- DROP INDEX IDX_Fleet_Center ON Fleet;
-- DROP INDEX IDX_HistoryLog_ChangeTime ON History_Log;

-- =============================================
-- A. 执行计划 (SHOWPLAN_TEXT)
-- =============================================
SET SHOWPLAN_TEXT ON;
GO

-- 1) 车牌号查询 (高频：车牌号)
SELECT plate_number, fleet_id, status
FROM Vehicle
WHERE plate_number = N'粤A-00001';
GO

-- 2) 运单日期范围查询 (高频：运单日期)
SELECT Order_id, vehicle_plate, driver_id, start_time, end_time
FROM [Order]
WHERE start_time >= DATEADD(DAY, -1, GETDATE())
  AND start_time < GETDATE();
GO

-- 3) 司机绩效查询 (高频：司机工号 + 运单日期)
SELECT Order_id, status, end_time
FROM [Order]
WHERE driver_id = N'DR001'
  AND status = 'Delivered'
  AND end_time >= DATEADD(DAY, -1, GETDATE())
  AND end_time < GETDATE();
GO

-- 4) 司机异常时间段查询 (高频：司机工号)
SELECT record_id, occur_time, exception_type, fine_amount, handle_status
FROM Exception_Record
WHERE driver_id = N'DR001'
  AND occur_time >= DATEADD(DAY, -1, GETDATE())
  AND occur_time < GETDATE()
ORDER BY occur_time DESC;
GO

-- 5) 车队+状态筛选车辆
SELECT plate_number, status
FROM Vehicle
WHERE fleet_id = 1 AND status = 'Idle';
GO

-- 6) 待分配运单列表
SELECT Order_id, status
FROM [Order]
WHERE status = 'Pending'
ORDER BY Order_id;
GO

SET SHOWPLAN_TEXT OFF;
GO

-- =============================================
-- B. IO/时间统计 (STATISTICS IO/TIME)
-- =============================================
SET STATISTICS IO, TIME ON;
GO

SELECT plate_number, fleet_id, status
FROM Vehicle
WHERE plate_number = N'粤A-00001';
GO

SELECT Order_id, vehicle_plate, driver_id, start_time, end_time
FROM [Order]
WHERE start_time >= DATEADD(DAY, -1, GETDATE())
  AND start_time < GETDATE();
GO

SELECT Order_id, status, end_time
FROM [Order]
WHERE driver_id = N'DR001'
  AND status = 'Delivered'
  AND end_time >= DATEADD(DAY, -1, GETDATE())
  AND end_time < GETDATE();
GO

SELECT record_id, occur_time, exception_type, fine_amount, handle_status
FROM Exception_Record
WHERE driver_id = N'DR001'
  AND occur_time >= DATEADD(DAY, -1, GETDATE())
  AND occur_time < GETDATE()
ORDER BY occur_time DESC;
GO

SELECT plate_number, status
FROM Vehicle
WHERE fleet_id = 1 AND status = 'Idle';
GO

SELECT Order_id, status
FROM [Order]
WHERE status = 'Pending'
ORDER BY Order_id;
GO

SET STATISTICS IO, TIME OFF;
GO
