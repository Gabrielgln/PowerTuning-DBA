use Traces

--------------------------------------------------------------------------------------------------------------------------------
--	Criação das tabelas para armazenar as informações
--------------------------------------------------------------------------------------------------------------------------------
if OBJECT_ID('Contador') is not null
	drop table Contador

if OBJECT_ID('Registro_Contador') is not null
	drop table Registro_Contador

CREATE TABLE Contador(Id_Contador INT identity, Nm_Contador VARCHAR(50))

INSERT INTO Contador (Nm_Contador)
SELECT 'BatchRequests'
INSERT INTO Contador (Nm_Contador)
SELECT 'User_Connection'
INSERT INTO Contador (Nm_Contador)
SELECT 'CPU'
INSERT INTO Contador (Nm_Contador)
SELECT 'Page Life Expectancy'

SELECT * FROM Contador

CREATE TABLE [dbo].[Registro_Contador](
	[Id_Registro_Contador] [int] IDENTITY(1,1) NOT NULL,
	[Dt_Log] [datetime] NULL,
	[Id_Contador] [int] NULL,
	[Valor] [int] NULL
) ON [PRIMARY]

--------------------------------------------------------------------------------------------------------------------------------
--	Criação da procedure para dar carga na tabela
--------------------------------------------------------------------------------------------------------------------------------
if OBJECT_ID('stpCarga_ContadoresSQL') is not null
	drop procedure stpCarga_ContadoresSQL

GO
CREATE PROCEDURE stpCarga_ContadoresSQL
AS
BEGIN
	DECLARE @BatchRequests INT,@User_Connection INT, @CPU INT, @PLE int

	DECLARE @RequestsPerSecondSample1	BIGINT
	DECLARE @RequestsPerSecondSample2	BIGINT

	SELECT @RequestsPerSecondSample1 = cntr_value FROM sys.dm_os_performance_counters WHERE counter_name = 'Batch Requests/sec'
	WAITFOR DELAY '00:00:05'
	SELECT @RequestsPerSecondSample2 = cntr_value FROM sys.dm_os_performance_counters WHERE counter_name = 'Batch Requests/sec'
	SELECT @BatchRequests = (@RequestsPerSecondSample2 - @RequestsPerSecondSample1)/5

	select @User_Connection = cntr_Value
	from sys.dm_os_performance_counters
	where counter_name = 'User Connections'
								
	SELECT  TOP(1) @CPU  = (SQLProcessUtilization + (100 - SystemIdle - SQLProcessUtilization ) )
	FROM ( 
		  SELECT record.value('(./Record/@id)[1]', 'int') AS record_id, 
				record.value('(./Record/SchedulerMonitorEvent/SystemHealth/SystemIdle)[1]', 'int') 
				AS [SystemIdle], 
				record.value('(./Record/SchedulerMonitorEvent/SystemHealth/ProcessUtilization)[1]', 
				'int') 
				AS [SQLProcessUtilization], [timestamp] 
		  FROM ( 
				SELECT [timestamp], CONVERT(xml, record) AS [record] 
				FROM sys.dm_os_ring_buffers 
				WHERE ring_buffer_type = N'RING_BUFFER_SCHEDULER_MONITOR' 
				AND record LIKE '%<SystemHealth>%') AS x 
		  ) AS y 
						  						  
	SELECT @PLE = cntr_value 
	FROM sys.dm_os_performance_counters
	WHERE 	counter_name = 'Page life expectancy'
		and object_name like '%Buffer Manager%'

	insert INTO Registro_Contador(Dt_Log,Id_Contador,Valor)
	Select GETDATE(), 1,@BatchRequests
	insert INTO Registro_Contador(Dt_Log,Id_Contador,Valor)
	Select GETDATE(), 2,@User_Connection

	insert INTO Registro_Contador(Dt_Log,Id_Contador,Valor)
	Select GETDATE(), 3,@CPU
	insert INTO Registro_Contador(Dt_Log,Id_Contador,Valor)
	Select GETDATE(), 4,@PLE
END
