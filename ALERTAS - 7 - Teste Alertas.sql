-- delete from Traces..Alerta where Dt_Alerta = getdate()-1
/*
Instruções para realizar os testes.

Colocar a execução da procedure stpAlerta_Queries_Demoradas no JOB de Traces.

Testar o alerta de lock sozinho

Executar os outros testes


*/


/*******************************************************************************************************************************
--	Cria a database de teste - Deve ser excluída no final do teste
*******************************************************************************************************************************/
USE [master]

IF EXISTS (SELECT NULL FROM sys.databases WHERE NAME = 'FabricioLimaConsultoria')
	DROP DATABASE [FabricioLimaConsultoria]

CREATE DATABASE [FabricioLimaConsultoria]

ALTER DATABASE [FabricioLimaConsultoria] SET RECOVERY SIMPLE

GO

/*******************************************************************************************************************************
--	Processo Bloqueado
*******************************************************************************************************************************/
USE [FabricioLimaConsultoria]

-- Cria uma tabela de teste
CREATE TABLE [dbo].[Teste_Lock] ([cod] INT)
	
INSERT INTO [dbo].[Teste_Lock] ([cod]) VALUES (6)
	
-- Executar em outra conexao (Conexao 1)
BEGIN TRAN
UPDATE [dbo].[Teste_Lock]
SET [cod] = [cod]

-- COMMIT
	
-- Executar em outra conexao (Conexao 2) - Ira ficar bloqueada!
BEGIN TRAN
UPDATE [dbo].[Teste_Lock]
SET [cod] = [cod]
	
-- COMMIT

-- Para conferir os Processos Bloqueados
EXEC [dbo].[sp_WhoIsActive]

-- ALERTA
-- Após 2 minutos de Lock, executar a procedure abaixo para enviar o ALERTA
EXEC [Traces].[dbo].[stpAlerta_Processo_Bloqueado]

-- CLEAR
-- Executar o COMMIT nas Conexoes 1 e 2. Por fim, executar a procedure abaixo para enviar o CLEAR
EXEC [Traces].[dbo].[stpAlerta_Processo_Bloqueado]

-- Exclui a tabela de Teste
DROP TABLE [dbo].[Teste_Lock]

GO

/*******************************************************************************************************************************
--	Arquivo de Log Full
*******************************************************************************************************************************/
USE [Traces]

-- ALERTA
UPDATE [dbo].[Alerta_Parametro]
SET [Vl_Parametro] = 1
WHERE Nm_Alerta = 'Arquivo de Log Full'

EXEC [dbo].[stpAlerta_Arquivo_Log_Full]

-- CLEAR
UPDATE [dbo].[Alerta_Parametro]
SET [Vl_Parametro] = 85
WHERE Nm_Alerta = 'Arquivo de Log Full'

EXEC [dbo].[stpAlerta_Arquivo_Log_Full]

GO

/*******************************************************************************************************************************
--	Espaco Disco
*******************************************************************************************************************************/
USE [Traces]

-- ALERTA
UPDATE [dbo].[Alerta_Parametro]
SET [Vl_Parametro] = 1
WHERE Nm_Alerta = 'Espaco Disco'

EXEC [dbo].[stpAlerta_Espaco_Disco]

-- CLEAR
UPDATE [dbo].[Alerta_Parametro]
SET [Vl_Parametro] = 85
WHERE Nm_Alerta = 'Espaco Disco'

EXEC [dbo].[stpAlerta_Espaco_Disco]

GO

/*******************************************************************************************************************************
--	Consumo CPU
*******************************************************************************************************************************/
USE [Traces]

-- ALERTA
UPDATE [dbo].[Alerta_Parametro]
SET [Vl_Parametro] = 1
WHERE Nm_Alerta = 'Consumo CPU'

EXEC [dbo].[stpAlerta_Consumo_CPU]

-- CLEAR
UPDATE [dbo].[Alerta_Parametro]
SET [Vl_Parametro] = 85
WHERE Nm_Alerta = 'Consumo CPU'

EXEC [dbo].[stpAlerta_Consumo_CPU]

GO

/*******************************************************************************************************************************
--	Conexão SQL Server
*******************************************************************************************************************************/
USE [Traces]

-- ALERTA
UPDATE [dbo].[Alerta_Parametro]
SET [Vl_Parametro] = 2
WHERE Nm_Alerta = 'Conexão SQL Server'

EXEC [dbo].[stpAlerta_Conexao_SQLServer]

-- CLEAR
UPDATE [dbo].[Alerta_Parametro]
SET [Vl_Parametro] = 2000
WHERE Nm_Alerta = 'Conexão SQL Server'

EXEC [dbo].[stpAlerta_Conexao_SQLServer]

GO

/*******************************************************************************************************************************
--	Status Database / Página Corrompida
*******************************************************************************************************************************/
USE [master]

-- ALERTA
ALTER DATABASE [FabricioLimaConsultoria] SET OFFLINE

EXEC [Traces].[dbo].[stpAlerta_Erro_Banco_Dados]

-- CLEAR
ALTER DATABASE [FabricioLimaConsultoria] SET ONLINE

EXEC [Traces].[dbo].[stpAlerta_Erro_Banco_Dados]

GO

/*******************************************************************************************************************************
--	Queries Demoradas
*******************************************************************************************************************************/
USE [Traces]

-- ALERTA
UPDATE [dbo].[Alerta_Parametro]
SET [Vl_Parametro] = 1
WHERE Nm_Alerta = 'Queries Demoradas'

EXEC [dbo].[stpAlerta_Queries_Demoradas]

-- Volta para o valor Default
UPDATE [dbo].[Alerta_Parametro]
SET [Vl_Parametro] = 100
WHERE Nm_Alerta = 'Queries Demoradas'

GO

/*******************************************************************************************************************************
--	Jobs Falharam
*******************************************************************************************************************************/
USE [Traces]

-- ALERTA
UPDATE [dbo].[Alerta_Parametro]
SET [Vl_Parametro] = 48
WHERE Nm_Alerta = 'Job Falha'

EXEC [dbo].[stpAlerta_Job_Falha]

-- Volta para o valor Default
UPDATE [dbo].[Alerta_Parametro]
SET [Vl_Parametro] = 24
WHERE Nm_Alerta = 'Job Falha'

GO

/*******************************************************************************************************************************
--	SQL Server Reiniciado
*******************************************************************************************************************************/
USE [Traces]

-- ALERTA
UPDATE [dbo].[Alerta_Parametro]
SET [Vl_Parametro] = 500000
WHERE Nm_Alerta = 'SQL Server Reiniciado'

EXEC [dbo].[stpAlerta_SQL_Server_Reiniciado]

-- Volta para o valor Default
UPDATE [dbo].[Alerta_Parametro]
SET [Vl_Parametro] = 20
WHERE Nm_Alerta = 'SQL Server Reiniciado'

GO

/*******************************************************************************************************************************
--	Database Criada
*******************************************************************************************************************************/
USE [Traces]

-- ALERTA
UPDATE [dbo].[Alerta_Parametro]
SET [Vl_Parametro] = 5000
WHERE Nm_Alerta = 'Database Criada'

EXEC [dbo].[stpAlerta_Database_Criada]

-- Volta para o valor Default
UPDATE [dbo].[Alerta_Parametro]
SET [Vl_Parametro] = 24
WHERE Nm_Alerta = 'Database Criada'

GO

/*******************************************************************************************************************************
--	Database sem Backup
*******************************************************************************************************************************/
USE [Traces]

-- ALERTA
UPDATE [dbo].[Alerta_Parametro]
SET [Vl_Parametro] = 0
WHERE Nm_Alerta = 'Database sem Backup'

EXEC [dbo].[stpAlerta_Database_Sem_Backup]

-- Volta para o valor Default
UPDATE [dbo].[Alerta_Parametro]
SET [Vl_Parametro] = 24
WHERE Nm_Alerta = 'Database sem Backup'

GO

/*******************************************************************************************************************************
--	Processos em Execução
*******************************************************************************************************************************/
USE [Traces]

EXEC [dbo].[stpEnvia_Email_Processos_Execucao]

GO

/*******************************************************************************************************************************
--	Alertas de Severidade
*******************************************************************************************************************************/
RAISERROR ('Teste Erro de Severidade', 21, 1) WITH LOG

GO

/*******************************************************************************************************************************
--	Confere o Resultado dos Testes dos Alertas
*******************************************************************************************************************************/
USE [Traces]

SELECT * FROM [dbo].[Alerta_Parametro] ORDER BY [Id_Alerta_Parametro]

SELECT * FROM [dbo].[Alerta] ORDER BY [Dt_Alerta] DESC

DROP DATABASE [FabricioLimaConsultoria]