-- Criando uma database para teste
--  DROP  DATABASE IF EXISTS [DBTailLog] --comando novo do sql 2016
CREATE DATABASE [DBTailLog];

GO
USE [DBTailLog];
GO
 
--Criando uma tabela
CREATE TABLE [TestTable] ([C1] INT IDENTITY, [C2] CHAR (100));
GO
 
-- Realizando um backup FULL
BACKUP DATABASE [DBTailLog] TO DISK = N'C:\TEMP\DBTailLog_Full.bak' WITH INIT,COMPRESSION;
GO
 
-- Inserindo algumas linhas
INSERT INTO [TestTable] VALUES ('Transaction 1');
INSERT INTO [TestTable] VALUES ('Transaction 2');
GO
 
-- Realizar um backup do Log
BACKUP LOG [DBTailLog] TO DISK = N'C:\TEMP\DBTailLog_Log1.bak' WITH INIT,COMPRESSION;
GO
 
-- Inserindo mais algumas linhas
INSERT INTO [TestTable] VALUES ('Transaction 3');
INSERT INTO [TestTable] VALUES ('Transaction 4');
GO

--simulando um desastre:

--Colocando a base como OFFLINE
ALTER DATABASE [DBTailLog] SET OFFLINE;

--Renomear o arquivo MDF

--Voltar a base para ONLINE
ALTER DATABASE DBTailLog SET ONLINE;

--Erro
Msg 5120, Level 16, State 101, Line 45
Unable to open the physical file "F:\RaizSQLServer\MSSQL13.MSSQLSERVER\MSSQL\DATA\DBTailLog.mdf". Operating system error 2: "2(O sistema não pode encontrar o arquivo especificado.)".
Msg 5181, Level 16, State 5, Line 45
Could not restart database "DBTailLog". Reverting to the previous status.
Msg 5069, Level 16, State 1, Line 45
ALTER DATABASE statement failed.


--Tentar acessar a base no object explorer

--Tentar executar um backup do log da forma normal
BACKUP LOG [DBTailLog] TO DISK = N'C:\TEMP\DBTailLog_Log2.bak' WITH COMPRESSION;

--Erro retornado
Msg 945, Level 14, State 2, Line 59
Database 'DBTailLog' cannot be opened due to inaccessible files or insufficient memory or disk space.  See the SQL Server errorlog for details.
Msg 3013, Level 16, State 1, Line 59
BACKUP LOG is terminating abnormally.


--Agora vamos realizar um backup do log com a opção NO_TRUNCATE, que permite realizar um backup mesmo se o arquivo da base não tiver disponível.

BACKUP LOG [DBTailLog] TO DISK = N'C:\TEMP\DBTailLog_Log2.bak' WITH COMPRESSION, NO_TRUNCATE

Processed 2 pages for database 'DBTailLog', file 'DBTailLog_log' on file 1.
BACKUP LOG successfully processed 2 pages in 0.129 seconds (0.094 MB/sec).

RESTORE FILELISTONLY
FROM DISK = 'C:\TEMP\DBTailLog_Full.bak'

--Restore com um novo Nome
RESTORE DATABASE DBTailLog_PosDesastre
FROM DISK = 'C:\TEMP\DBTailLog_Full.bak'
WITH NORECOVERY,STATS = 5,
MOVE 'DBTailLog' TO 'C:\TEMP\DBTailLog_PosDesastre.mdf'
,MOVE 'DBTailLog_log' TO 'C:\TEMP\DBTailLog_PosDesastre_Log.ldf'

RESTORE LOG DBTailLog_PosDesastre
FROM DISK = 'C:\TEMP\DBTailLog_Log1.bak'
WITH NORECOVERY

RESTORE LOG DBTailLog_PosDesastre
FROM DISK = 'C:\TEMP\DBTailLog_Log2.bak'
WITH RECOVERY

--Todas as transações estão aqui. Mesmo aquela que não tinham backup antes do desastre acontecer.
select * from DBTailLog_PosDesastre..TestTable

--Para voltar a base
--Deixe ela OFFLINE
alter database DBTailLog set OFFLINE

--Altere novamente o nome do arquivo para o correto

--Deixe ela ONLINE
alter database DBTailLog set ONLINE

--Excluindo a base de teste
use master

Drop database DBTailLog

drop database DBTailLog_PosDesastre









