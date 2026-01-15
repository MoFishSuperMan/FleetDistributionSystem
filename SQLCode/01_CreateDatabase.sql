USE master;
GO

-- 检查数据库是否存在，如果存在则删除（慎用，开发环境使用）
IF EXISTS (SELECT * FROM sys.databases WHERE name = 'FleetDistributionDB')
BEGIN
    ALTER DATABASE FleetDistributionDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE FleetDistributionDB;
END
GO

-- 创建数据库
CREATE DATABASE FleetDistributionDB;
GO

USE FleetDistributionDB;
GO
