USE FleetDistributionDB;
GO

-- =============================================
-- 07. 模拟广州物流中心数据脚本
-- 覆盖场景：基础CRUD、运单分配与超载拦截、状态流转、异常处理、审计日志
-- =============================================

-- 0. 清空数据
EXEC sp_msforeachtable "ALTER TABLE ? NOCHECK CONSTRAINT all"
GO
DELETE FROM History_Log; -- 也要清空日志以便测试观察
DELETE FROM Exception_Record;
DELETE FROM [Order];
DELETE FROM Driver;
DELETE FROM Vehicle;
DELETE FROM Dispatcher;
DELETE FROM Fleet;
DELETE FROM Distribution_Center;
GO
DBCC CHECKIDENT ('History_Log', RESEED, 0);
DBCC CHECKIDENT ('Exception_Record', RESEED, 0);
DBCC CHECKIDENT ('Fleet', RESEED, 0);
DBCC CHECKIDENT ('Distribution_Center', RESEED, 0);
GO
EXEC sp_msforeachtable "ALTER TABLE ? WITH CHECK CHECK CONSTRAINT all"
GO

-- 1. 插入配送中心
-- 模拟广州中心
INSERT INTO Distribution_Center (center_name, address) VALUES 
('广州物流中心', '广州市白云区太和镇物流大道168号'), 
('深圳分拨中心', '深圳市宝安区福永街道'); -- 即使不用也留一个备用
GO

-- 2. 插入车队 (隶属广州中心 ID=1)
INSERT INTO Fleet (fleet_name, center_id) VALUES 
('广州快运队', 1),  -- fleed_id = 1
('华南重卡队', 1),  -- fleed_id = 2
('测试专用队', 1);  -- fleed_id = 3
GO

-- 3. 插入调度主管 (Dispatcher)
-- 密码默认 123456
INSERT INTO Dispatcher (dispatcher_id, name, password, fleet_id) VALUES 
('DP001', '张主管(快运)', '123456', 1),
('DP002', '李主管(重卡)', '123456', 2),
('DP000', '测试主管',     '123456', 3);
GO

-- 4. 插入车辆
-- A. 广州快运队 (fleet_id=1): 城市配送轻型车
INSERT INTO Vehicle (plate_number, fleet_id, max_weight, max_volume, status) VALUES 
('粤A-00001', 1, 5.00, 15.00, 'Idle'),         -- 空闲，用于正常分配
('粤A-00002', 1, 2.00, 5.00,  'Idle'),         -- 载重小，用于超载测试
('粤A-00003', 1, 5.00, 15.00, 'Busy'),         -- 运输中，用于验证状态流转
('粤A-00004', 1, 5.00, 15.00, 'Exception');    -- 异常，用于异常处理恢复测试

-- B. 华南重卡队 (fleet_id=2): 干线重卡
INSERT INTO Vehicle (plate_number, fleet_id, max_weight, max_volume, status) VALUES 
('粤B-99999', 2, 30.00, 100.00, 'Maintenance'); -- 维修中

-- C. 测试队 (fleet_id=3)
INSERT INTO Vehicle (plate_number, fleet_id, max_weight, max_volume, status) VALUES 
('粤Z-TEST1', 3, 10.00, 30.00, 'Idle');
GO

-- 5. 插入司机
-- 默认密码 123456
INSERT INTO Driver (driver_id, name, password, license_level, phone, fleet_id) VALUES 
-- 所属 广州快运队 (1)
('DR001', '陈师傅', '123456', 'C1', '13800000001', 1), -- 匹配 粤A-00001
('DR002', '林师傅', '123456', 'B2', '13800000002', 1), -- 匹配 粤A-00002
('DR003', '黄师傅', '123456', 'C1', '13800000003', 1), -- 匹配 粤A-00003 (忙)
('DR004', '张三疯', '123456', 'C1', '13800000004', 1), -- 匹配 粤A-00004 (异常)

-- 所属 华南重卡队 (2)
('DR005', '王重阳', '123456', 'A1', '13900000005', 2),

-- 所属 测试队 (3)
('DR000', '测试员', '123456', 'C1', '13666666666', 3);
GO

-- 6. 插入运单 (Order)
INSERT INTO [Order] (Order_id, cargo_weight, cargo_volume, destination, status, vehicle_plate, driver_id, start_time, end_time) VALUES 
-- 1. 待分配新订单 (用于分配测试)
('ORD-GZ-001', 3.50, 10.00, '广州天河', 'Pending', NULL, NULL, NULL, NULL),
('ORD-GZ-002', 10.00, 20.00, '佛山顺德', 'Pending', NULL, NULL, NULL, NULL), -- 重量较大，测试超载

-- 2. 正在运输的订单 (关联 粤A-00003, DR003)
('ORD-GZ-003', 3.00, 8.00, '东莞南城', 'In-Transit', '粤A-00003', 'DR003', DATEADD(HOUR, -2, GETDATE()), NULL),

-- 3. 历史已完成订单 (用于报表统计)
('ORD-GZ-HIST1', 4.00, 12.00, '深圳南山', 'Delivered', '粤A-00001', 'DR001', DATEADD(DAY, -5, GETDATE()), DATEADD(DAY, -4, GETDATE())),
('ORD-GZ-HIST2', 4.50, 12.00, '珠海香洲', 'Delivered', '粤A-00001', 'DR001', DATEADD(DAY, -3, GETDATE()), DATEADD(DAY, -2, GETDATE()));
GO

-- 7. 插入异常记录 (Exception_Record)
INSERT INTO Exception_Record (vehicle_plate, driver_id, occur_time, exception_type, specific_event, fine_amount, handle_status, description) VALUES 
-- 1. 已处理的历史异常 (用于报表)
('粤A-00001', 'DR001', DATEADD(DAY, -10, GETDATE()), 'Idle_Exception', '车辆未按时归队', 200.00, 'Processed', '已扣除奖金'),

-- 2. 未处理的当前异常 (关联 粤A-00004) -> 触发器应该在插入时将车辆状态置为 Exception (这里直接插入数据，状态在Vehicle插入时已设为Exception)
('粤A-00004', 'DR004', DATEADD(HOUR, -1, GETDATE()), 'Transit_Exception', '车辆抛锚', 500.00, 'Unprocessed', '等待维修救援');
GO
