--Criação da database
USE master 
IF DATABASEPROPERTYEX (N'CHECKSUM', N'Version') > 0
BEGIN
	ALTER DATABASE CHECKSUM SET SINGLE_USER
		WITH ROLLBACK IMMEDIATE;
	DROP DATABASE CHECKSUM;
END

CREATE DATABASE CHECKSUM 


USE CHECKSUM;

--Criação da tabela que vamos corromper
CREATE TABLE [RandomData] (
	[c1]  INT IDENTITY,
	[c2]  CHAR (8000) DEFAULT 'a');
GO

--inserindo 10 linhas na tabela de uma vez
INSERT INTO [RandomData] DEFAULT VALUES;
GO 10

BACKUP DATABASE CHECKSUM
TO DISK = 'C:\Temp\CHECKSUM_Dados.bak'
WITH INIT,COMPRESSION,CHECKSUM,STATS = 5

-- Escolhendo uma das páginas dessa database para corromper. Vou escolher a página de número 118
DBCC IND (N'CHECKSUM', N'RandomData', -1);
GO

-- Comando para corromper uma base de dados ******* NUNCA RODEM ISSO EM UMA BASE DE PRODUÇÃO!!!!!!!! 
ALTER DATABASE CHECKSUM SET SINGLE_USER;
GO
DBCC WRITEPAGE (N'CHECKSUM', 1, 256, 0, 2, 0x0000, 1);
GO
ALTER DATABASE CHECKSUM SET MULTI_USER;
GO

-- Como a base está marcada como CHECKSUM, ao tentar executar o SELECT o SQL Server já identifica uma corrupção
SELECT	*
FROM [CHECKSUM].[dbo].[RandomData];

-- DBCC CHECKDB('CHECKSUM')

-- Essa tabela mostra quantas vezes tentaram realizar uma consulta nessa página corrompida
SELECT	* FROM	[msdb].[dbo].[suspect_pages];

--Passa um tempo.... o banco tem backups de log sendo executados...
BACKUP LOG CHECKSUM
TO DISK = 'C:\Temp\CHECKSUM_Logs.bak'
WITH INIT,COMPRESSION,CHECKSUM,STATS = 5

--recebeu um alerta e descobriu que tinha uma página corrompida.
-------------------------

--Primeira coisa: Qual é a tabela afetada?

SELECT	* FROM	[msdb].[dbo].[suspect_pages];

--Antes do SQL 2012
DBCC TRACEON (3604);
DBCC PAGE (11, 1, 256, 0) WITH TABLERESULTS;
DBCC TRACEOFF (3604);

Metadata: ObjectId = 565577053 --linha 25

use CHECKSUM
SELECT OBJECT_NAME (565577053)

--A partir do SQL 2012
SELECT DB_NAME(susp.database_id) DatabaseName,
	OBJECT_SCHEMA_NAME(ind.object_id, ind.database_id) ObjectSchemaName,
	OBJECT_NAME(ind.object_id, ind.database_id) ObjectName, *
FROM msdb.dbo.suspect_pages susp
CROSS APPLY SYS.DM_DB_DATABASE_PAGE_ALLOCATIONS(susp.database_id,null,null,null,null) ind
WHERE allocated_page_file_id = susp.file_id
	AND allocated_page_page_id = susp.page_id
	
Fonte: http://www.sqlskills.com/blogs/paul/finding-table-name-page-id/


------------------------- Restaurando a página de dados

ALTER DATABASE CHECKSUM SET SINGLE_USER;

use master

RESTORE DATABASE CHECKSUM
PAGE = '1:256'  -- e.g. 1:5224,1:5225,etc
FROM DISK = 'C:\Temp\CHECKSUM_Dados.bak'
WITH NORECOVERY

RESTORE LOG CHECKSUM
FROM DISK = 'C:\Temp\CHECKSUM_Logs.bak'
WITH RECOVERY

dbcc CHECKDB('CHECKSUM')

SELECT	*
FROM [CHECKSUM].[dbo].[RandomData];

Msg 829, Level 21, State 1, Line 2
Database ID 6, Page (1:118) is marked RestorePending, which may indicate disk corruption. To recover from this state, perform a restore.

-- Para concluir o restore de pagina, deve-se realizar um novo backup de log para pegar tudo que foi alterado até esse momento e restaurar
BACKUP LOG CHECKSUM
TO DISK = 'C:\Temp\CHECKSUM_Logs2.bak'
WITH INIT,COMPRESSION,CHECKSUM,STATS = 5

RESTORE LOG CHECKSUM
FROM DISK = 'C:\Temp\CHECKSUM_Logs2.bak'
WITH RECOVERY

dbcc CHECKDB('CHECKSUM')

SELECT	*
FROM [CHECKSUM].[dbo].[RandomData];

ALTER DATABASE CHECKSUM SET MULTI_USER;

SELECT	*
FROM [CHECKSUM].[dbo].[RandomData];

Be aware that page restore cannot be used to restore: 
full-text, allocation pages (GAM, SGAM, PFS, DIFF, ML), file header page (PageId =0 ), boot page (PageId =9).

