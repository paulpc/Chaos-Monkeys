USE [CompletionsProblem]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[udf_MilesBetweenPoints]') AND type in (N'FN', N'IF', N'TF', N'FS', N'FT'))
BEGIN
execute dbo.sp_executesql @statement = N'
CREATE FUNCTION [dbo].[udf_MilesBetweenPoints](@source geography, @destination geography)
returns NUMERIC(18,8)
AS
BEGIN
return @source.STDistance(@destination)/1609.34
END
' 
END

GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Production]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[Production](
	[WellName] [nvarchar](50) NULL,
	[ProductionTime] [datetime] NULL,
	[BOPD] [numeric](18, 8) NULL,
	[MCFD] [numeric](18, 8) NULL,
	[BWPD] [numeric](18, 8) NULL,
	[Pressure] [numeric](18, 8) NULL
)
END
GO
SET ANSI_PADDING ON

GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[Production]') AND name = N'CIDX_Production')
CREATE CLUSTERED INDEX [CIDX_Production] ON [dbo].[Production]
(
	[WellName] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[dbo].[ProductionStatistics]'))
EXEC dbo.sp_executesql @statement = N'
CREATE VIEW [dbo].[ProductionStatistics]
AS
WITH LastEvent
AS
(
SELECT WellName, MAX(ProductionTime) as [LastEvent], DATEADD(day, -1, MAX(ProductionTime)) as LowerBound
FROM dbo.Production
GROUP BY WellName
)
SELECT p.WellName
, AVG(p.BOPD) AS avgBOPD
, STDEV(p.BOPD) as stdBOPD
, VAR(p.BOPD) as varBOPD
, AVG(p.MCFD) AS avgMCFD
, STDEV(p.MCFD) as stdMCFD
, VAR(p.MCFD) as varMCFD
, AVG(p.BWPD) AS avgBWPD
, STDEV(p.BWPD) as stdBWPD
, VAR(p.BWPD) as varBWPD
, AVG(p.Pressure) as avgPressure
, STDEV(p.Pressure) as stdPressure
, VAR(p.Pressure) as varPressure
FROM dbo.Production p
INNER JOIN LastEvent le
ON p.WellName = le.WellName
AND (p.ProductionTime <= le.LastEvent
AND p.ProductionTime >= le.LowerBound)
GROUP BY p.WellName

' 
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Wells]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[Wells](
	[WellID] [int] IDENTITY(1,1) NOT NULL,
	[WellName] [nvarchar](100) NOT NULL,
	[Location] [geography] NULL,
PRIMARY KEY CLUSTERED 
(
	[WellID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
)
END
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[dbo].[NearbyWells]'))
EXEC dbo.sp_executesql @statement = N'


CREATE VIEW [dbo].[NearbyWells]
AS
SELECT wl1.wellname, wl2.wellname as targetwell
, dbo.udf_MilesBetweenPoints(wl1.location, wl2.location) as [Distance_mi]
FROM dbo.wells WL1
CROSS JOIN dbo.wells wl2
WHERE wl1.wellid <> wl2.wellid



' 
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[dbo].[NearbyWellStatistics]'))
EXEC dbo.sp_executesql @statement = N'CREATE VIEW [dbo].[NearbyWellStatistics]
AS
SELECT w.WellName, w.Distance_mi, c.WellName as NearbyWell
	, c.avgBOPD, c.stdBOPD, c.varBOPD
	, c.avgMCFD, c.stdMCFD, c.varMCFD
	, c.avgBWPD, c.stdBWPD, c.varBWPD
	, c.avgPressure, c.stdPressure 
FROM dbo.NearbyWells w
INNER JOIN dbo.ProductionStatistics c
	ON w.targetwell = c.wellname
WHERE w.Distance_mi <= 5.0' 
GO
