--------------------------------------------------------------------------------------------------------------------------------
--	1)	Testes de Backup
--------------------------------------------------------------------------------------------------------------------------------
--	Alterando o Recovery Model da base para FULL para que eu possa realizar Backups do Log
ALTER DATABASE TreinamentoDBA SET RECOVERY FULL

--	Realizando um Backup FULL
BACKUP DATABASE TreinamentoDBA
TO DISK = 'C:\TEMP\TreinamentoDBA_Dados.bak'
WITH INIT, COMPRESSION, CHECKSUM, STATS = 5 ,NAME = 'C:\TEMP\TreinamentoDBA_Dados.bak'

--	Realizando um Backup Diferencial
BACKUP DATABASE TreinamentoDBA
TO DISK = 'C:\TEMP\TreinamentoDBA_Diff.bak'
WITH DIFFERENTIAL, INIT, COMPRESSION, CHECKSUM, STATS = 5,NAME = 'C:\TEMP\TreinamentoDBA_Diff.bak'

--	Realizando um Backup do Log
BACKUP LOG TreinamentoDBA
TO DISK = 'C:\TEMP\TreinamentoDBA_Log_1.bak'
WITH INIT, COMPRESSION, CHECKSUM,NAME = 'C:\TEMP\TreinamentoDBA_Log_1.bak'

--	Realizando outro Backup do Log
BACKUP LOG TreinamentoDBA
TO DISK = 'C:\TEMP\TreinamentoDBA_Log_2.bak'
WITH INIT, COMPRESSION, CHECKSUM,NAME = 'C:\TEMP\TreinamentoDBA_Log_2.bak'


--------------------------------------------------------------------------------------------------------------------------------
--	Query para conferir o histórico de Backups que foram executados
--------------------------------------------------------------------------------------------------------------------------------
SELECT	database_name, name,backup_start_date, datediff(mi, backup_start_date, backup_finish_date) [tempo (min)],
		position, server_name, recovery_model, isnull(logical_device_name, ' ') logical_device_name, device_type, 
		type, cast(backup_size/1024/1024 as numeric(15,2)) [Tamanho (MB)]
FROM msdb.dbo.backupset B
	  INNER JOIN msdb.dbo.backupmediafamily BF ON B.media_set_id = BF.media_set_id
where backup_start_date >=  dateadd(hh, -24 ,getdate()  )
--  and type in ('D','I')
order by backup_start_date desc

--	Guardem muito bem essa query que utilizaram uma infinidade de vezes como DBA para conferir Backups!!!
--	D = FULL, I = Diferencial, L = Log


--------------------------------------------------------------------------------------------------------------------------------
--	2)	Backup com a opção CHECKSUM
--------------------------------------------------------------------------------------------------------------------------------
--	Criação da database
USE master 
IF DATABASEPROPERTYEX (N'CHECKSUM', N'Version') > 0
BEGIN
	ALTER DATABASE CHECKSUM SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
	DROP DATABASE CHECKSUM;
END

CREATE DATABASE CHECKSUM 

--	Criação de uma tabela e inserção de 10 linhas nessa tabela
USE CHECKSUM;
CREATE TABLE [RandomData] (
	[c1]  INT IDENTITY,
	[c2]  CHAR (8000) DEFAULT 'a');
GO

INSERT INTO [RandomData] DEFAULT VALUES;
GO 10

--	Listando as páginas dessa tabela
DBCC IND (N'CHECKSUM', N'RandomData', -1);
GO

/*******************************************************************************************************************************
----------------------------------------------------- <<< PERIGO!!!!! >>> ------------------------------------------------------
*******************************************************************************************************************************/
--	Comando para corromper uma base de dados ******* NUNCA RODEM ISSO EM UMA BASE DE PRODUÇÃO!!!!!!!!
ALTER DATABASE CHECKSUM SET SINGLE_USER;
GO
DBCC WRITEPAGE (N'CHECKSUM', 1, 264, 0, 2, 0x0000, 1);
GO
ALTER DATABASE CHECKSUM SET MULTI_USER;
GO
/*******************************************************************************************************************************
----------------------------------------------------- <<< PERIGO!!!!! >>> ------------------------------------------------------
*******************************************************************************************************************************/

--	Realizando um Backup SEM a opção CHECKSUM
BACKUP DATABASE CHECKSUM
TO DISK = 'C:\TEMP\CHECKSUM_Dados.bak'
WITH INIT, COMPRESSION, STATS = 10,NAME = 'C:\TEMP\CHECKSUM_Dados.bak - SEM CHECKSUM'

--	Realizando um Backup COM a opção CHECKSUM
BACKUP DATABASE CHECKSUM
TO DISK = 'C:\TEMP\CHECKSUM_Dados.bak'
WITH INIT, COMPRESSION, CHECKSUM, STATS = 10,NAME = 'C:\TEMP\CHECKSUM_Dados.bak - COM CHECKSUM'

--	Erro que é gerado
Msg 3043, Level 16, State 1, Line 98
BACKUP 'CHECKSUM' detected an error on page (1:264) in file 'F:\RaizSQLServer\MSSQL13.MSSQLSERVER\MSSQL\DATA\CHECKSUM.mdf'.
Msg 3013, Level 16, State 1, Line 98
BACKUP DATABASE is terminating abnormally.


--	Utilizando a opção CHECKSUM conseguimos aproveitar a executação do Backup e já fazer essa mínima verificação de corrupção. 
--	Dessa forma, pegamos um erro de corrupção antes da rotina de CHECKDB ser executada.
--	Quanto mais rápido identificarmos uma corrupção melhor.


--------------------------------------------------------------------------------------------------------------------------------
--	3)	Abrir o script de Backup FULL
--------------------------------------------------------------------------------------------------------------------------------
--	Uma rotina de Backup varia muito de ambiente para ambiente. Depende do tamanho das bases, do tempo de execução e do espaço em disco disponível.

--	Segue um script com uma rotina de Backup onde podemos armazenar 1 Backup FULL ou uma semana inteira de Backup FULL.

--	"..\Tarefas do dia a dia de um DBA\Modulo 04 - Backup e Restore\Procedure Backup FULL Databases.sql"


--------------------------------------------------------------------------------------------------------------------------------
--	4)	Backup de Log
--------------------------------------------------------------------------------------------------------------------------------

-- Usava script

-- Agora estou usando plano de manutenção

-- Desabilitar o job de backup do log para não atrapalhar a demo de restore

--------------------------------------------------------------------------------------------------------------------------------
--	5)	Restore
--------------------------------------------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------------------------------------------
--	5.1)	Realizando um Backup da database "TreinamentoDBA" e executando um Restore por cima dessa database
--------------------------------------------------------------------------------------------------------------------------------
BACKUP DATABASE TreinamentoDBA
TO DISK = 'C:\TEMP\TreinamentoDBA_Dados.bak'
WITH INIT, COMPRESSION, CHECKSUM, STATS = 10,NAME = 'C:\TEMP\TreinamentoDBA_Dados.bak'

--	Restore por cima de uma database já existente
RESTORE DATABASE TreinamentoDBA
FROM DISK = 'C:\TEMP\TreinamentoDBA_Dados.bak'
WITH RECOVERY, REPLACE, STATS = 5

--------------------------------------------------------------------------------------------------------------------------------
--	5.2)	Realizando um Restore de uma database que ainda não existe
--------------------------------------------------------------------------------------------------------------------------------

USE MASTER 

--	Exclui a database caso ela já exista
IF DATABASEPROPERTYEX (N'TreinamentoDBA_TesteRestore', N'Version') > 0
BEGIN
	ALTER DATABASE TreinamentoDBA_TesteRestore SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
	DROP DATABASE TreinamentoDBA_TesteRestore;
END

--	Apenas para validar o nome lógico dos arquivos de dados e logs
RESTORE FILELISTONLY
FROM DISK = 'C:\TEMP\TreinamentoDBA_Dados.bak'

-- Restore criando uma nova database
RESTORE DATABASE TreinamentoDBA_TesteRestore
FROM DISK = 'C:\TEMP\TreinamentoDBA_Dados.bak'
WITH RECOVERY,STATS = 5,
MOVE 'TreinamentoDBA' TO 'C:\TEMP\TreinamentoDBA_TesteRestore.mdf',
MOVE 'TreinamentoDBA_log' TO 'C:\TEMP\TreinamentoDBA_TesteRestore_Log.ldf'

--	Conferir a base criada no caminho: C:\TEMP\

--------------------------------------------------------------------------------------------------------------------------------
-- 5.3) Testes de restores (FULL, Diferencial e Logs)
--------------------------------------------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------------------------------------------
--	5.3.1)	Populando uma tabela e realizando Backups. Simulando o que acontece em um ambiente real.
--------------------------------------------------------------------------------------------------------------------------------
use TreinamentoDBA

--	Cria uma tabela de teste
if object_Id('Teste_Restore') is not null
	drop table Teste_Restore

create Table Teste_Restore(
	Cod int identity,
	Dt_log datetime default(getdate()),
	Descricao varchar(100)
)

--	Insere um registro na tabela de teste
insert into Teste_Restore(Descricao)
select 'Antes Backup Full'

--	Realiza um Backup FULL
BACKUP DATABASE TreinamentoDBA
TO DISK = 'C:\TEMP\TreinamentoDBA_Dados.bak'
WITH INIT,COMPRESSION,CHECKSUM,STATS = 10,
	NAME = 'C:\TEMP\TreinamentoDBA_Dados.bak'
	
--	Insere um registro na tabela de teste
insert into Teste_Restore(Descricao)
select 'Antes Backup Diferencial'

--	Realiza um Backup Diferencial
BACKUP DATABASE TreinamentoDBA
TO DISK = 'C:\TEMP\TreinamentoDBA_Diff.bak'
WITH DIFFERENTIAL, INIT,COMPRESSION,CHECKSUM,STATS = 10,
	NAME = 'C:\TEMP\TreinamentoDBA_Diff.bak'

--	Insere um registro na tabela de teste
insert into Teste_Restore(Descricao)
select 'Antes Backup Log 1'

--	Realiza um Backup do Log
BACKUP LOG TreinamentoDBA
TO DISK = 'C:\TEMP\LOG\TreinamentoDBA_Log1.bak'
WITH INIT,COMPRESSION,CHECKSUM,
	name = 'TreinamentoDBA_Log1'	

--	Insere um registro na tabela de teste
insert into Teste_Restore(Descricao)
select 'Antes Backup Log 2'

--	Realiza uma espera de 5 segundos
waitfor delay '00:00:05'

--	Insere um registro na tabela de teste
insert into Teste_Restore(Descricao)
select 'Antes Backup Log 2 após 5 segundos'

--	Realiza um Backup do Log
BACKUP LOG TreinamentoDBA
TO DISK = 'C:\TEMP\LOG\TreinamentoDBA_Log2.bak'
WITH INIT, COMPRESSION,CHECKSUM,
	name = 'TreinamentoDBA_Log2'	

--	Conferindo os registros inseridos
select * from TreinamentoDBA..Teste_Restore

--	Conferindo os Backups realizados da database "TreinamentoDBA"
SELECT database_name, name, backup_start_date, datediff(mi,backup_start_date,backup_finish_date) [tempo (min)],
	  position, server_name, recovery_model, last_lsn,
	  isnull(logical_device_name,' ') logical_device_name,device_type,type, cast(backup_size/1024/1024 as numeric(15,2)) [Tamanho (MB)],first_lsn
FROM msdb.dbo.backupset B
	  INNER JOIN msdb.dbo.backupmediafamily BF ON B.media_set_id = BF.media_set_id
where backup_start_date >=  dateadd(hh, -24 ,getdate()  )
	and database_name = 'TreinamentoDBA'
order by backup_start_date desc

--------------------------------------------------------------------------------------------------------------------------------
--	5.3.2)	Restore FULL
--------------------------------------------------------------------------------------------------------------------------------
USE MASTER

RESTORE DATABASE TreinamentoDBA
FROM DISK = 'C:\TEMP\TreinamentoDBA_Dados.bak'
WITH RECOVERY, REPLACE, STATS = 5

--	Após o restore FULL só temos uma linha
select * from TreinamentoDBA..Teste_Restore

--------------------------------------------------------------------------------------------------------------------------------
--	5.3.3)	Restore FULL + Diferencial
--------------------------------------------------------------------------------------------------------------------------------
--	Restore FULL
RESTORE DATABASE TreinamentoDBA
FROM DISK = 'C:\TEMP\TreinamentoDBA_Dados.bak'
WITH NORECOVERY, REPLACE, STATS = 5

--	Restore Diferencial
RESTORE DATABASE TreinamentoDBA
FROM DISK = 'C:\TEMP\TreinamentoDBA_Diff.bak'
WITH RECOVERY, STATS = 5

--	Após o restore FULL + Diferencial temos duas linhas
select * from TreinamentoDBA..Teste_Restore

--------------------------------------------------------------------------------------------------------------------------------
--	5.3.4)	Restore FULL + Diferencial + Log
--------------------------------------------------------------------------------------------------------------------------------
--	Conferindo novamente a sequencia de backup para que possamos restaurar
SELECT database_name, name,backup_start_date, datediff(mi,backup_start_date,backup_finish_date) [tempo (min)],
	  position,server_name,recovery_model,
	  isnull (logical_device_name,' ') logical_device_name,device_type,type, cast(backup_size/1024/1024 as numeric(15,2)) [Tamanho (MB)],first_lsn
FROM msdb.dbo.backupset B
	  INNER JOIN msdb.dbo.backupmediafamily BF ON B.media_set_id = BF.media_set_id
where backup_start_date >=  dateadd(hh, -24 ,getdate()  )
	and database_name = 'TreinamentoDBA'
order by backup_start_date desc

use master

--	Restore FULL
RESTORE DATABASE TreinamentoDBA
FROM DISK = 'C:\TEMP\TreinamentoDBA_Dados.bak'
WITH NORECOVERY, REPLACE, STATS = 5

--	Restore Diferencial
RESTORE DATABASE TreinamentoDBA
FROM disk = 'C:\TEMP\TreinamentoDBA_Diff.bak'
WITH NORECOVERY, REPLACE, STATS = 5

--	Restore de 1 Backup do Log
RESTORE LOG TreinamentoDBA
FROM DISK = 'C:\TEMP\Log\TreinamentoDBA_Log1.bak'
WITH NORECOVERY

--	Comando para deixar a database ONLINE
restore database TreinamentoDBA with recovery

--	Conferindo os dados restaurados
select * from TreinamentoDBA..Teste_Restore

--------------------------------------------------------------------------------------------------------------------------------
--	5.3.5)	Restore FULL + Diferencial + Log + Log
--------------------------------------------------------------------------------------------------------------------------------
use master

--	Restore FULL
RESTORE DATABASE TreinamentoDBA
FROM DISK = 'C:\TEMP\TreinamentoDBA_Dados.bak'
WITH NORECOVERY, REPLACE, STATS = 5

--	Restore Diferencial
RESTORE DATABASE TreinamentoDBA
FROM DISK = 'C:\TEMP\TreinamentoDBA_Diff.bak'
WITH NORECOVERY, STATS = 5

--	Restore Log
RESTORE LOG TreinamentoDBA
FROM DISK = 'C:\TEMP\Log\TreinamentoDBA_Log1.bak'
WITH NORECOVERY

--	Restore Log
RESTORE LOG TreinamentoDBA
FROM DISK = 'C:\TEMP\Log\TreinamentoDBA_Log2.bak'
WITH RECOVERY

--	Conferindo os dados restaurados
select * from TreinamentoDBA..Teste_Restore

--------------------------------------------------------------------------------------------------------------------------------
--	5.3.6)	Restore FULL + Diferencial + Log + Log com STOP AT
--------------------------------------------------------------------------------------------------------------------------------
--	Conferindo até que exato momento vamos restaurar
select * from TreinamentoDBA..Teste_Restore

--	Restore FULL
RESTORE DATABASE TreinamentoDBA
FROM DISK = 'C:\TEMP\TreinamentoDBA_Dados.bak'
WITH NORECOVERY, REPLACE, STATS = 5

--	Restore Diferencial
RESTORE DATABASE TreinamentoDBA
FROM DISK = 'C:\TEMP\TreinamentoDBA_Diff.bak'
WITH NORECOVERY, REPLACE, STATS = 5

--	Restore Log
RESTORE LOG TreinamentoDBA
FROM DISK = 'C:\TEMP\Log\TreinamentoDBA_Log1.bak'
WITH NORECOVERY

--	Restore Log até às XX horas
RESTORE LOG TreinamentoDBA
FROM DISK = 'C:\TEMP\Log\TreinamentoDBA_Log2.bak'
WITH RECOVERY,STOPAT = '2017-07-18 11:42:06.753'

--	Conferindo os dados restaurados
select * from TreinamentoDBA..Teste_Restore

--	Query para verificar os Restores que já foram realizados
--	OBS: Essa tabela não armazena o número da posição do arquivo no Backup do Log.
select * 
from msdb.dbo.restorehistory
order by restore_date desc

--	Esse restore com STOP AT é muito importante para voltar um update ou delete errado que alguém executou na base de dados.
--	Com ele conseguimos voltar até segundos antes do horário que a pessoa fez a "cagada/merda/orelhada"


--------------------------------------------------------------------------------------------------------------------------------
--	6)	Teste de um Script de Restore
--------------------------------------------------------------------------------------------------------------------------------
--	Em um ambiente com muitos Backups, para facilitar a minha vida, 
--  criei um script que me retorna os comandos que devo executar
--	para restaurar os Backups FULL, Diferencial e do Log.

--------------------------------------------------------------------------------------------------------------------------------
--	Executar os Backups abaixo para restaurar a base
--------------------------------------------------------------------------------------------------------------------------------
--	Backup FULL
BACKUP DATABASE TreinamentoDBA
TO DISK = 'C:\TEMP\TreinamentoDBA_Dados.bak'
WITH INIT, COMPRESSION, CHECKSUM, STATS = 10,
	NAME = 'C:\TEMP\TreinamentoDBA_Dados.bak'

--	Backup Diferencial
BACKUP DATABASE TreinamentoDBA
TO DISK = 'C:\TEMP\TreinamentoDBA_Diff.bak'
WITH DIFFERENTIAL, INIT, COMPRESSION, CHECKSUM, STATS = 10,
	NAME = 'C:\TEMP\TreinamentoDBA_Diff.bak'
		
insert into TreinamentoDBA..Teste_Restore(Descricao)
select 'TESTE DE SCRIPT DE BACKUP DO LOG'

--	Conferindo os registros inseridos
select * from TreinamentoDBA..Teste_Restore

-- Backup do Log Inicial
EXEC msdb.dbo.sp_start_job N'DBA - Backup Log.DBA - Backup Log' ;  


--	Conferindo novamente a sequencia de backup para que possamos restaurar
SELECT database_name, name,backup_start_date, datediff(mi,backup_start_date,backup_finish_date) [tempo (min)],
	  position,server_name,recovery_model,
	  isnull (logical_device_name,' ') logical_device_name,device_type,type, cast(backup_size/1024/1024 as numeric(15,2)) [Tamanho (MB)],first_lsn
FROM msdb.dbo.backupset B
	  INNER JOIN msdb.dbo.backupmediafamily BF ON B.media_set_id = BF.media_set_id
where backup_start_date >=  dateadd(hh, -24 ,getdate())
	and database_name = 'TreinamentoDBA'
order by backup_start_date desc


--	Abrir o script abaixo e testar (antes simular os backups abaixo):
--	"...\Modulo 04 - Backup e Restore\Script Backup Log\(sua versao)..."

--	Para conferir o restore






--------------------- CONTEUDO PLUS -----------------------

-- Esse conteúdo abaixo não tinha nas turmas iniciais, mas com o tempo que ganhamos com os vídeos consigo incluir esses assuntos

--------------------- Backup com Mirror
BACKUP DATABASE TreinamentoDBA
TO DISK = 'C:\TEMP\TreinamentoDBA_Dados.bak'
	MIRROR TO DISK = 'C:\TEMP\BKP1\TreinamentoDBA_Dados.bak'
	MIRROR TO DISK = 'C:\TEMP\BKP2\TreinamentoDBA_Dados.bak'
WITH INIT, COMPRESSION, CHECKSUM, STATS = 10,FORMAT,
	NAME = 'C:\TEMP\TreinamentoDBA_Dados.bak'


--Leitura complementar: https://spaghettidba.com/2011/12/29/mirrored-backups-a-usefu-feature/


----------------- Verificar um backup
RESTORE VERIFYONLY 
FROM DISK ='C:\TEMP\TreinamentoDBA_Dados.bak'

--Leitura complementar: https://www.simple-talk.com/sql/backup-and-recovery/backup-verification-tips-for-database-backup-testing/

/*
VERIFYONLY will process the backup and perform several checks. First, it can find and read the backup file. 
Believe it or not, that’s a good first step. Far too many people will assume that they can restore a file that is either incomplete or inaccessible. 
It also walks through the CHECKSUM information if you used CHECKSUM in the backup (see above). This will validate that the backup media is in place. 
That can be a costly operation if the backup file is very large, so I don’t know that I’d run this check from my production system if I could help it. 
Finally, VERIFYONLY checks some of the header information in the backup.
 It doesn’t check all the header information, so it’s still possible for a backup to pass VERIFYONLY but still not restore successfully to the server. 
 Which brings up the best way to validate your backups, RESTORE.
 */

----------------- Backup com Standby
use TreinamentoDBA

--	Cria uma tabela de teste
if object_Id('Teste_Restore') is not null
	drop table Teste_Restore

create Table Teste_Restore(
	Cod int identity,
	Dt_log datetime default(getdate()),
	Descricao varchar(100)
)

--	Insere um registro na tabela de teste
insert into Teste_Restore(Descricao)
select 'Antes Backup Full'

--	Backup FULL
BACKUP DATABASE TreinamentoDBA
TO DISK = 'C:\TEMP\TreinamentoDBA_Standby_Dados.bak'
WITH INIT, COMPRESSION, CHECKSUM, STATS = 10,
	NAME = 'C:\TEMP\TreinamentoDBA_Standby_Dados.bak'
	
--	Backup Diferencial
BACKUP DATABASE TreinamentoDBA
TO DISK = 'C:\TEMP\TreinamentoDBA_Diff.bak'
WITH DIFFERENTIAL, INIT, COMPRESSION, CHECKSUM, STATS = 10,
	NAME = 'C:\TEMP\TreinamentoDBA_Diff.bak'
GO

--	Insere um registro na tabela de teste
insert into Teste_Restore(Descricao)
select 'Antes Backup Log Inicial'
GO 10

--	Backup do Log Inicial
BACKUP LOG TreinamentoDBA
TO DISK = 'C:\TEMP\TreinamentoDBA_Log.bak'
WITH INIT, COMPRESSION, CHECKSUM,
	name = 'C:\TEMP\TreinamentoDBA_Log.bak'
GO
insert into Teste_Restore(Descricao)
select 'Antes Backup Log Incremental'
GO 10

--Backup do Log Incremental
--	Antes de executar o Restore, realizar mais vários backups do log (rodar 5 vezes)
BACKUP LOG TreinamentoDBA
TO DISK = 'C:\TEMP\TreinamentoDBA_Log.bak'
WITH NOINIT, COMPRESSION, CHECKSUM,
	name = 'C:\TEMP\TreinamentoDBA_Log.bak'

-- Restaurando os arquivos

--	Restore FULL
RESTORE DATABASE TreinamentoDBA
FROM DISK = 'C:\TEMP\TreinamentoDBA_Standby_Dados.bak'
WITH NORECOVERY, REPLACE, STATS = 5

--	Restore Diferencial
RESTORE DATABASE TreinamentoDBA
FROM DISK = 'C:\TEMP\TreinamentoDBA_Diff.bak'
WITH NORECOVERY, REPLACE, STATS = 5

--	Restore Log 1 
RESTORE LOG TreinamentoDBA
FROM DISK = 'C:\TEMP\TreinamentoDBA_Log.bak'
WITH STANDBY='C:\TEMP\TreinamentoDBA_standby_file.bak',FILE = 1

--confere os dados
select * from TreinamentoDBA..Teste_Restore

--	Restore Log 2 apenas para validação
RESTORE LOG TreinamentoDBA
FROM DISK = 'C:\TEMP\TreinamentoDBA_Log.bak'
WITH STANDBY='C:\TEMP\TreinamentoDBA_standby_file.bak',FILE = 2

--confere os dados
select * from TreinamentoDBA..Teste_Restore

--Era isso que eu queria. Vou deixar a base ONLINE.
restore database TreinamentoDBA with recovery



------	Backup TailLog:

--	"...\DEMO - Backup TailLog.sql"


------	Page Restore:

--	"...\DEMO - Page Restore.sql"