SET NOCOUNT ON

---------------------------------------------------------------------------------------------------------------------------------
-- Parametros para realizar o Backup
--------------------------------------------------------------------------------------------------------------------------------
DECLARE @DatabaseDestino VARCHAR(8000), @Ds_Caminho_StandyBy VARCHAR(8000), @Ds_Pasta_Log VARCHAR(8000), @Nm_Arquivo_Log VARCHAR(8000),
		@Ds_Caminho_Backup_Full VARCHAR(8000), @Ds_Caminho_Backup_Diff VARCHAR(8000), @Ds_Extensao_Backup_Log VARCHAR(8000),
		@ComandoBackupFULL varchar(8000), @ComandoBackupDiferencial varchar(8000), @ComandoBackupLog varchar(8000),
		@DatabaseOrigem varchar(8000)
		
select	@DatabaseOrigem = 'TreinamentoDBA',
		@DatabaseDestino = 'TreinamentoDBA_TURMA15',		
		@Ds_Caminho_Backup_Full = 'C:\TEMP\TreinamentoDBA_Dados.bak', --caminho\nome do backup full
		@Ds_Caminho_Backup_Diff = 'C:\TEMP\TreinamentoDBA_Diff.bak',  --caminho\nome do backup diferencial
		@Ds_Caminho_StandyBy = NULL,	-- Informar o nome do arquivo para o Standy By, caso contrário deve informar NULL	
		@Ds_Extensao_Backup_Log = '.trn',
		@Ds_Pasta_Log = 'C:\TEMP\Backup\Log\TreinamentoDBA\' -- Na pasta deve existir apenas arquivos de LOG!

/*
Xp_dirtree has three parameters: 

subdirectory	- This is the directory you pass when you call the stored procedure; for example 'D:\Backup'.
depth			- This tells the stored procedure how many subfolder levels to display.  The default of 0 will display all subfolders.
file			- This will either display files as well as each folder.  The default of 0 will not display any files.
*/

IF (OBJECT_ID('tempdb..#Lista_Arquivos_Log') IS NOT NULL)
	DROP TABLE #Lista_Arquivos_Log

create table #Lista_Arquivos_Log(
	[subdirectory] varchar(500),
	[depth] TINYINT,
	[file] TINYINT
)

INSERT INTO #Lista_Arquivos_Log([subdirectory], [depth], [file])
EXEC Master.dbo.xp_DirTree @Ds_Pasta_Log, 1, 1

-- Exclui os arquivos que não são de Backup
DELETE #Lista_Arquivos_Log
WHERE RIGHT(subdirectory, len(@Ds_Extensao_Backup_Log)) <> @Ds_Extensao_Backup_Log

-- https://dba.stackexchange.com/questions/12437/extracting-a-field-from-restore-headeronly

-- https://docs.microsoft.com/en-us/sql/t-sql/statements/restore-statements-headeronly-transact-sql

IF (OBJECT_ID('tempdb..#BackupHeader') IS NOT NULL)
	DROP TABLE #BackupHeader

CREATE TABLE #BackupHeader
( 
    BackupName varchar(256),
    BackupDescription varchar(256),
    BackupType varchar(256),        
    ExpirationDate varchar(256),
    Compressed varchar(256),
    Position varchar(256),
    DeviceType varchar(256),        
    UserName varchar(256),
    ServerName varchar(256),
    DatabaseName varchar(256),
    DatabaseVersion varchar(256),        
    DatabaseCreationDate varchar(256),
    BackupSize varchar(256),
    FirstLSN varchar(256),
    LastLSN varchar(256),        
    CheckpointLSN varchar(256),
    DatabaseBackupLSN varchar(256),
    BackupStartDate DATETIME,
    BackupFinishDate DATETIME,        
    SortOrder varchar(256),
    CodePage varchar(256),
    UnicodeLocaleId varchar(256),
    UnicodeComparisonStyle varchar(256),        
    CompatibilityLevel varchar(256),
    SoftwareVendorId varchar(256),
    SoftwareVersionMajor varchar(256),        
    SoftwareVersionMinor varchar(256),
    SoftwareVersionBuild varchar(256),
    MachineName varchar(256),
    Flags varchar(256),        
    BindingID varchar(256),
    RecoveryForkID varchar(256),
    Collation varchar(256),
    FamilyGUID varchar(256),        
    HasBulkLoggedData varchar(256),
    IsSnapshot varchar(256),
    IsReadOnly varchar(256),
    IsSingleUser varchar(256),        
    HasBackupChecksums varchar(256),
    IsDamaged varchar(256),
    BeginsLogChain varchar(256),
    HasIncompleteMetaData varchar(256),        
    IsForceOffline varchar(256),
    IsCopyOnly varchar(256),
    FirstRecoveryForkID varchar(256),
    ForkPointLSN varchar(256),        
    RecoveryModel varchar(256),
    DifferentialBaseLSN varchar(256),
    DifferentialBaseGUID varchar(256),        
    BackupTypeDescription varchar(256),
    BackupSetGUID varchar(256),
    CompressedBackupSize varchar(256),
	Containment tinyint						-- Include this column if using SQL 2012
    --KeyAlgorithm nvarchar(32),			-- Include this column if using SQL 2014
    --EncryptorThumbprint varbinary(20),	-- Include this column if using SQL 2014
    --EncryptorType nvarchar(32)			-- Include this column if using SQL 2014
)

INSERT INTO #BackupHeader
exec ('RESTORE HEADERONLY FROM DISK = ''' + @Ds_Caminho_Backup_Full + '''')

IF (@Ds_Caminho_Backup_Diff IS NOT NULL)
BEGIN
	INSERT INTO #BackupHeader
	exec ('RESTORE HEADERONLY FROM DISK = ''' + @Ds_Caminho_Backup_Diff + '''')
END

IF (OBJECT_ID('tempdb..#BackupHeaderLog') IS NOT NULL)
	DROP TABLE #BackupHeaderLog

SELECT identity(int,1,1) ID, *
INTO #BackupHeaderLog
FROM #Lista_Arquivos_Log

WHILE EXISTS (SELECT TOP 1 ID FROM #BackupHeaderLog)
BEGIN
	select top 1 @Nm_Arquivo_Log = @Ds_Pasta_Log + subdirectory
	from #BackupHeaderLog
	order by ID

	INSERT INTO #BackupHeader
	exec ('RESTORE HEADERONLY FROM DISK = ''' + @Nm_Arquivo_Log + '''')

	delete from #BackupHeaderLog where ID = (SELECT MIN(ID) FROM #BackupHeaderLog)
END

-- Exclui Backups sem nome
DELETE #BackupHeader
WHERE BackupName IS NULL

-- Exclui Backups que não são da base especificada
DELETE #BackupHeader
WHERE DatabaseName <> @DatabaseOrigem

---------------------------------------------------------------------------------------------------------------------------------
-- Busca os nomes lógicos dos arquivos
--------------------------------------------------------------------------------------------------------------------------------
if object_id('tempdb..#Filelistonly') is not null drop table #Filelistonly

Create table #Filelistonly
(
	LogicalName          nvarchar(128),
	PhysicalName         nvarchar(260),
	[Type]               char(1),
	FileGroupName        nvarchar(128),
	Size                 numeric(20,0),
	MaxSize              numeric(20,0),
	FileID               bigint,
	CreateLSN            numeric(25,0),
	DropLSN              numeric(25,0),
	UniqueID             uniqueidentifier,
	ReadOnlyLSN          numeric(25,0),
	ReadWriteLSN         numeric(25,0),
	BackupSizeInBytes    bigint,
	SourceBlockSize      int,
	FileGroupID          int,
	LogGroupGUID         uniqueidentifier,
	DifferentialBaseLSN  numeric(25,0),
	DifferentialBaseGUID uniqueidentifier,
	IsReadOnl            bit,
	IsPresent            bit,
	TDEThumbprint        varbinary(32)		-- Remove this column if using SQL 2005
	--SnapshotURL          nvarchar(360)	-- Include this column if using SQL 2016
)

INSERT INTO #Filelistonly
exec('RESTORE FILELISTONLY FROM DISK = ''' + @Ds_Caminho_Backup_Full + '''')

declare @logicalnameDATA varchar(MAX), @logicalnameLOG varchar(MAX), @physicalnameDATA varchar(MAX), @physicalnameLOG varchar(MAX)

select @logicalnameDATA = logicalname, @physicalnameDATA = physicalname
from #Filelistonly
where type = 'D'

select @logicalnameLOG = logicalname, @physicalnameLOG = physicalname
from #Filelistonly
where type = 'L'

select	@physicalnameDATA = replace(@physicalnameDATA,'.mdf', '_'+@DatabaseDestino+'.mdf'), 
		@physicalnameLOG = replace(@physicalnameLOG,'.ldf','_'+@DatabaseDestino+'.ldf')
	
--------------------------------------------------------------------------------------------------------------------------------
-- VERIFICA AS DATAS DOS BACKUPS FULL E DIFERENCIAL
--------------------------------------------------------------------------------------------------------------------------------
declare @Ultimo_Backup_FULL datetime, @Ultimo_Backup_Diferencial datetime

-- Backup Full
select @Ultimo_Backup_FULL = BackupFinishDate 
from #BackupHeader 
where BackupType = 1

-- Backup Diferencial - Se a data do diferencial for menor que o FULL, o valor fica NULL
SELECT @Ultimo_Backup_Diferencial = CASE WHEN BackupFinishDate > @Ultimo_Backup_FULL THEN BackupFinishDate ELSE NULL END
FROM #BackupHeader 
WHERE	BackupType = 5
		AND BackupStartDate >= @Ultimo_Backup_FULL

--------------------------------------------------------------------------------------------------------------------------------
-- RESTORE FULL
--------------------------------------------------------------------------------------------------------------------------------
PRINT '-- FULL
RESTORE DATABASE ' + @DatabaseDestino + '
FROM DISK = ''' + @Ds_Caminho_Backup_Full + ''' 
WITH	NORECOVERY , STATS = 1,
		MOVE ''' + @logicalnameDATA + ''' TO '''  + @physicalnameDATA + ''',
		MOVE ''' + @logicalnameLOG	+ ''' TO '''  + @physicalnameLOG  + ''''

--------------------------------------------------------------------------------------------------------------------------------
--	RESTORE DIFERENCIAL
--------------------------------------------------------------------------------------------------------------------------------
IF (@Ultimo_Backup_Diferencial IS NOT NULL)
BEGIN
	PRINT '

-- DIFERENCIAL
RESTORE DATABASE ' + @DatabaseDestino + ' 
FROM DISK = ''' + @Ds_Caminho_Backup_Diff + ''' 
WITH NORECOVERY, STATS = 1' 
END


---------------------------------------------------------------------------------------------------------------------------------
--	RESTORE LOG
--------------------------------------------------------------------------------------------------------------------------------
/*
Backup type:
	1 = Database				-- Backup Full
	2 = Transaction log			-- Backup Log
	4 = File
	5 = Differential database	-- Backup Diferencial
	6 = Differential file
	7 = Partial
	8 = Differential partial
*/

-- Backup Log
DELETE #BackupHeader
WHERE BackupType <> 2

DELETE #BackupHeader
WHERE BackupType = 2 AND BackupStartDate < ISNULL(@Ultimo_Backup_Diferencial,@Ultimo_Backup_FULL)

PRINT '

-- LOG'

while exists ( select TOP 1 NULL from #BackupHeader)
begin	
	SELECT TOP 1 @ComandoBackupLog  =
		'RESTORE LOG '+ @DatabaseDestino +' from disk = ''' + @Ds_Pasta_Log + [BackupName] + @Ds_Extensao_Backup_Log + ''' WITH FILE = 1' + 
		+ CASE WHEN @Ds_Caminho_StandyBy IS NOT NULL THEN ', STANDBY = N''' + @Ds_Caminho_StandyBy + '''' ELSE ', NORECOVERY' END
	from #BackupHeader
	order by BackupStartDate

	PRINT @ComandoBackupLog

	delete from #BackupHeader where [BackupName] = (SELECT TOP 1 [BackupName] FROM #BackupHeader order by BackupStartDate)
end

PRINT ''
PRINT ''
PRINT '-- Comando para deixar a base ONLINE'
PRINT 'RESTORE DATABASE ' + @DatabaseDestino + ' WITH RECOVERY'