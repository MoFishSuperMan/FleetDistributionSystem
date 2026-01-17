USE FleetDistributionDB;
GO

SET NOCOUNT ON;

-- =============================================
-- 批量造数脚本（默认各 100000 条，可自行调整）
-- 说明：
-- 1) 生成运单时，大部分为 Delivered，少量为 Pending（不分配车辆/司机）
-- 2) Delivered 运单分配车辆/司机同车队，避免触发器报错
-- 3) 异常记录主要给 DR001，用于索引测试
-- =============================================

DECLARE @OrderRows INT = 100000;
DECLARE @ExceptionRows INT = 100000;

-- 司机-车辆配对（确保同车队）
DECLARE @Pairs TABLE (
    pair_id INT PRIMARY KEY,
    vehicle_plate NVARCHAR(20),
    driver_id NVARCHAR(20)
);

INSERT INTO @Pairs (pair_id, vehicle_plate, driver_id) VALUES
(1, N'粤A-00001', N'DR001'),
(2, N'粤A-00002', N'DR002'),
(3, N'粤A-00003', N'DR003'),
(4, N'粤A-00004', N'DR004'),
(5, N'粤B-99999', N'DR005'),
(6, N'粤Z-TEST1', N'DR000');

-- 计算已存在的批量运单号最大值，避免重复
DECLARE @StartNo INT = ISNULL((
    SELECT MAX(CAST(SUBSTRING(Order_id, 10, 6) AS INT))
    FROM [Order]
    WHERE Order_id LIKE 'ORD-BULK-%'
), 0);

;WITH nums AS (
    SELECT TOP (@OrderRows)
        ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM sys.all_objects
)
INSERT INTO [Order] (
    Order_id,
    cargo_weight,
    cargo_volume,
    destination,
    status,
    vehicle_plate,
    driver_id,
    start_time,
    end_time
)
SELECT
    CONCAT('ORD-BULK-', RIGHT('000000' + CAST(n + @StartNo AS NVARCHAR(10)), 6)) AS Order_id,
    CAST(1 + (n % 9) * 0.5 AS DECIMAL(10, 2)) AS cargo_weight,
    CAST(2 + (n % 10) * 0.8 AS DECIMAL(10, 2)) AS cargo_volume,
    CONCAT(N'批量目的地-', RIGHT('00000' + CAST(n AS NVARCHAR(10)), 5)) AS destination,
    CASE WHEN n % 5 = 0 THEN 'Pending' ELSE 'Delivered' END AS status,
    CASE WHEN n % 5 = 0 THEN NULL ELSE p.vehicle_plate END AS vehicle_plate,
    CASE WHEN n % 5 = 0 THEN NULL ELSE p.driver_id END AS driver_id,
    CASE WHEN n % 5 = 0 THEN NULL ELSE DATEADD(DAY, -((n % 60) + 1), GETDATE()) END AS start_time,
    CASE WHEN n % 5 = 0 THEN NULL ELSE DATEADD(HOUR, 2, DATEADD(DAY, -((n % 60) + 1), GETDATE())) END AS end_time
FROM nums
CROSS APPLY (
    SELECT vehicle_plate, driver_id
    FROM @Pairs
    WHERE pair_id = ((n - 1) % 6) + 1
) p;

;WITH nums AS (
    SELECT TOP (@ExceptionRows)
        ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM sys.all_objects
)
INSERT INTO Exception_Record (
    vehicle_plate,
    driver_id,
    occur_time,
    exception_type,
    specific_event,
    fine_amount,
    handle_status,
    description
)
SELECT
    CASE WHEN n % 4 = 0 THEN NULL ELSE N'粤A-00001' END AS vehicle_plate,
    N'DR001' AS driver_id,
    DATEADD(HOUR, -((n % 720) + 1), GETDATE()) AS occur_time,
    CASE WHEN n % 2 = 0 THEN 'Transit_Exception' ELSE 'Idle_Exception' END AS exception_type,
    CASE WHEN n % 2 = 0 THEN N'运输延误' ELSE N'空闲违规' END AS specific_event,
    CAST((n % 10) * 20 AS DECIMAL(10, 2)) AS fine_amount,
    CASE WHEN n % 3 = 0 THEN 'Processed' ELSE 'Unprocessed' END AS handle_status,
    N'批量生成异常' AS description
FROM nums;

PRINT '批量造数完成。';
GO
