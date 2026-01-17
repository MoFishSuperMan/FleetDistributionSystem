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
