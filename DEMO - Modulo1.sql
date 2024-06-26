--------------------------------------------------------------------------------------------------------------------------------
--	Testes Collation
--------------------------------------------------------------------------------------------------------------------------------
--	1)	Retorna a collation de uma database
SELECT DATABASEPROPERTYEX('TreinamentoDBA', 'Collation') SQLCollation

--	2)	Retorna a collation da instância do SQL Server
select SERVERPROPERTY(N'Collation')

--	3)	Criando uma database chamada "TesteCollation" com a collation diferente do servidor: "Latin1_General_CI_AS"
if exists(select name from sys.databases where name = 'TesteCollation')
	drop database TesteCollation

CREATE DATABASE [TesteCollation]
 ON  PRIMARY 
( NAME = N'TesteCollation', 
FILENAME = N'C:\TEMP\TesteCollation.mdf',
SIZE = 5120KB, FILEGROWTH = 1024KB )
 LOG ON 
( NAME = N'TesteCollation_log', 
FILENAME = N'C:\TEMP\TesteCollation_log.ldf',
SIZE = 1024KB, FILEGROWTH = 10%)
 COLLATE Latin1_General_CI_AS

--	4)	Conferindo que a collation da base e do servidor são diferentes
--	Nova Database
SELECT DATABASEPROPERTYEX('TesteCollation', 'Collation') SQLCollation

--	Servidor
select SERVERPROPERTY(N'Collation')

--	Verificando a collation de todas as databases
select name, collation_name 
from sys.databases

--	5)	Criando uma tabela na base TesteCollation e uma tabela temporária para simular o problema que isso pode gerar.
use TesteCollation
Create table Cliente(Cod int identity, Nome varchar(50))

insert into Cliente
select 'Fabricio Lima'

Create table #Cliente2(Cod int identity, Nome varchar(50))

insert into #Cliente2
select 'Fabricio Lima'

--	6)	Realizando um join entre uma tabela temporária e uma tabela da base de dados TesteCollation. 
select *
from #Cliente2 A
join Cliente B on A.Nome = B.Nome

--	Recebemos o erro:
--	Msg 468, Level 16, State 9, Line 3
--	Cannot resolve the collation conflict between "Latin1_General_CI_AS" and "Latin1_General_CI_AI" in the equal to operation.

--	7)	Como resolver?
select *
from #Cliente2 A
join Cliente B on A.Nome collate Latin1_General_CI_AI = B.Nome

--	Colocando o comando "collate Latin1_General_CI_AI" convertemos o resultado da coluna A.Nome para a collation Latin1_General_CI_AI
--	que é igual a coluna da base.

use master
drop database TesteCollation


------	Curiosidade. Conversão para retirar todos os acentos de uma string.

Declare @cExpressao varchar(30)
Set @cExpressao = 'aeiouáéíóúàèìòòâêîôûãõäëïöüç'
Select @cExpressao ANTES,@cExpressao collate sql_latin1_general_cp1251_ci_as DEPOIS


------------------ Collation pode impactar na PERFORMANCE? ----------------------------------
https://www.fabriciolima.net/blog/2017/02/06/video-melhorando-a-performance-de-uma-consulta-com-like-string-alterando-a-collation/

use TreinamentoDBA

--DROP TABLE IF EXISTS dbo.Teste_Collation_SQL

-- Cria e popula a tabela com vários registros
create table dbo.Teste_Collation_SQL (
	cod int identity(1,1) PRIMARY KEY,
	Dt_Log datetime,
	Descrição varchar(50)
)

-- Popula a tabela (pode demorar alguns minutos)
insert into dbo.Teste_Collation_SQL
select getdate(), REPLICATE('A',50)
go 10

--15 segundos
insert into dbo.Teste_Collation_SQL(Dt_Log,Descrição)
SELECT Dt_Log,Descrição
FROM Teste_Collation_SQL
GO 18

insert into dbo.Teste_Collation_SQL
select getdate(), 'Fabricio Lima 1'

insert into dbo.Teste_Collation_SQL
select getdate(), '- Fabricio Lima 2'

CREATE NONCLUSTERED INDEX SK01_Teste_Collation_SQL ON Teste_Collation_SQL(Descrição)  WITH(FILLFACTOR=95)

sp_spaceused Teste_Collation_SQL

SET STATISTICS IO ON 
SET STATISTICS TIME ON
-- CTRL+M

-- Teste 1: usando a collation da minha coluna: Latin1_General_CI_AI
SELECT COUNT(*)
FROM TreinamentoDBA..Teste_Collation_SQL
WHERE Descrição LIKE '%Fabricio%'

--Consumo CPU

-- Teste 2: usando a collation da minha coluna: Latin1_General_CI_AI
SELECT COUNT(*)
FROM TreinamentoDBA..Teste_Collation_SQL
WHERE Descrição COLLATE SQL_Latin1_General_CP1_CI_AI LIKE '%Fabricio%'

  
--Rodando o Teste 1 forçando a collation da coluna (que não faz diferença nenhuma)
SELECT COUNT(*)
FROM TreinamentoDBA..Teste_Collation_SQL
WHERE Descrição COLLATE Latin1_General_CI_AI LIKE  '%Fabricio%'

-- Curiosidade: A collation BIN é ainda mais rápido, contudo ela é case sensitive e acent sensitive... 
-- Se você tivesse uma collation Latin1_General_CS_AS, você poderia fazer o like com a Latin1_General_BIN2 
SELECT COUNT(*)
FROM TreinamentoDBA..Teste_Collation_SQL
WHERE Descrição COLLATE Latin1_General_BIN2 LIKE '%Fabricio%'

-- link referência explicando um pouco do motivo disso acontecer.
-- https://support.microsoft.com/en-us/help/322112/comparing-sql-collations-to-windows-collations

--Obs.: Se usar uma coluna Nvarchar ao invés de varchar, isso não acontece. O tempo é o mesmo.


-- Voltar para o Slide

--------------------------------------------------------------------------------------------------------------------------------
--	Teste execução da procedure que limpa o errorlog
--------------------------------------------------------------------------------------------------------------------------------

exec sp_cycle_errorlog

--------------------------------------------------------------------------------------------------------------------------------
--	IFI -> Instant File Initialization
--------------------------------------------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------------------------------------------
--	Passo a passo para habilitar o IFI (Instant File Initialization):
--------------------------------------------------------------------------------------------------------------------------------
--	1)	Run secpol.msc on the server.

--	2)	Execute o comando "secpol.msc"
--	OBS: O comando "secpol.msc" não funciona em algumas edições do Windows: "Home Premium" ou "Basic" Editions.

--	3)	Em "Security Settings" -> "Local Policies" -> Clique em "User Rights Assignment".

--	4)	Na listagem do lado direito, clique duas vezes em "Perform volume maintenance tasks".  (se tiver em portugues: Executar tarefas de manutenção de volume)

--	5)	O usuário do serviço do SQL Server deve ser adicionado aí.
--	OBS: Para verificar o usuário do serviço, abra o "SQL Configuration Manager" -> "SQL Server Services"
--		 -> Verificar a coluna "Log On As" da instância desejada.

--	6)	Se o usuário não estiver listado, clique em "Add User or Group" -> Adicione o usuário -> Clique em "OK" -> "Apply".

--	7)	Feito isso, agora reinicie o SQL Server.

--	Único Risco:  By granting “Perform Volume Maintenance Tasks” to a SQL Server instance, you are giving administrators of the 
--	instance the ability to read the encrypted contents of a recently deleted file (ONLY IF the file system decides to use this 
--	newly freed space on the creation of a new database – created with instant initialization) with the undocumented DBCC PAGE command.


--------------------------------------------------------------------------------------------------------------------------------
--	Script para validar o IFI está habilitado no seu SQL Server
--------------------------------------------------------------------------------------------------------------------------------
--	Fonte: http://sqlblog.com/blogs/tibor_karaszi/archive/2013/10/30/check-for-instant-file-initialization.aspx

USE MASTER;
SET NOCOUNT ON

-- *** WARNING: Undocumented commands used in this script !!! *** --

--	Exit if a database named DummyTestDB exists
IF DB_ID('DummyTestDB') IS NOT NULL
BEGIN
	RAISERROR('A database named DummyTestDB already exists, exiting script', 20, 1) WITH LOG
END

--	Temptable to hold output from sp_readerrorlog
IF OBJECT_ID('tempdb..#SqlLogs') IS NOT NULL DROP TABLE #SqlLogs
GO
CREATE TABLE #SqlLogs(LogDate datetime2(0), ProcessInfo VARCHAR(20), TEXT VARCHAR(MAX))

--	Turn on trace flags 3004 and 3605
DBCC TRACEON(3004, 3605, -1) WITH NO_INFOMSGS

--	Create a dummy database to see the output in the SQL Server Errorlog
CREATE DATABASE DummyTestDB 
GO

--	Turn off trace flags 3004 and 3605
DBCC TRACEOFF(3004, 3605, -1) WITH NO_INFOMSGS

--	Remove the DummyDB
DROP DATABASE DummyTestDB;

--	Now go check the output in the SQL Server Error Log File
--	This can take a while if you have a large errorlog file
INSERT INTO #SqlLogs(LogDate, ProcessInfo, TEXT)
EXEC sp_readerrorlog 0, 1, 'Zeroing'

IF EXISTS(
           SELECT * FROM #SqlLogs
           WHERE TEXT LIKE 'Zeroing completed%'
            AND TEXT LIKE '%DummyTestDB.mdf%'
            AND LogDate > DATEADD(HOUR, -1, LogDate)
        )
BEGIN
	PRINT 'We do NOT have Instant File Initialization (IFI).'
	PRINT 'Grant the SQL Server services account the ''Perform Volume Maintenance Tasks'' security policy.'
END
ELSE
BEGIN
	PRINT 'We have Instant File Initialization (IFI).'
END


--------------------------------------------------------------------------------------------------------------------------------
--	Script para realizar um teste de restore com e sem IFI habilitado
--------------------------------------------------------------------------------------------------------------------------------
--Criação de uma base de dados para teste vazia mas com um arquivo de 5 GB
if exists(select null from sys.databases where name = 'TESTE_IFI')
	Drop database TESTE_IFI

CREATE DATABASE [TESTE_IFI]
 CONTAINMENT = NONE
 ON  PRIMARY 
( NAME = N'TESTE_IFI', 
FILENAME = N'C:\TEMP\TESTE_IFI.mdf' , 
SIZE = 20 GB , FILEGROWTH = 1024KB )
 LOG ON ( NAME = N'TESTE_IFI_log', 
FILENAME = N'C:\TEMP\TESTE_IFI_log.ldf' , 
SIZE = 1024KB , FILEGROWTH = 10%)
GO


--Realização do backup da base. O arquivo de backup é bem pequeno porque a base não tem dados.
backup database TESTE_IFI
to disk = 'C:\TEMP\TESTE_IFI_Dados.bak'
with COMPRESSION,STATS=1,INIT


--1) Excluir a base e fazer um restore com e sem IFI habilitado
if exists(select null from sys.databases where name = 'TESTE_IFI')
Drop database TESTE_IFI

Restore database TESTE_IFI
from disk = 'C:\TEMP\TESTE_IFI_Dados.bak'
with stats=1

if exists(select null from sys.databases where name = 'TESTE_IFI')
Drop database TESTE_IFI

--------------------------------------------------------------------------------------------------------------------------------
--	Testes Database Mail
--------------------------------------------------------------------------------------------------------------------------------
--	1)	Envio de um e-mail simples via o DatabaseMail
EXEC msdb.dbo.sp_send_dbmail
		@profile_name = 'MSSQLServer',
		@recipients = 'fabricioflima@gmail.com',
		@body = 'Se você receber esse e-mail, o recurso Database Mail está funcionando',
		@subject = 'Verificação do Recurso Database Mail' 

--	2)	Query para acompanhar os e-mails que estão sendo enviados
select top 5 sent_status,* from msdb.dbo.sysmail_unsentitems order by send_request_date desc

--	3)	Query para acompanhar o status de envio dos e-mails
select top 5 sent_status,* from msdb.dbo.sysmail_mailitems order by send_request_date desc

--	Sent_Status (column on [msdb].[dbo].[sysmail_mailitems] table): 
--	0 - unsent
--	1 - sent
--	2 - failed (default)
--	3 - retrying