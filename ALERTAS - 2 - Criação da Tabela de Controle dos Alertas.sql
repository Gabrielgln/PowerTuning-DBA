/*******************************************************************************************************************************
(C) 2016, Fabricio Lima Solu��es em Banco de Dados

Site: http://www.fabriciolima.net/

Feedback: contato@fabriciolima.net
*******************************************************************************************************************************/


/*******************************************************************************************************************************
--	Instru��es de utiliza��o do script.
*******************************************************************************************************************************/
--	1) Substituir o e-mail "E-mail@provedor.com" pelos emails que devem receber os Alertas

DECLARE @Ds_Email VARCHAR(MAX)

SELECT @Ds_Email = 'E-mail@provedor.com'

--	2) Basta aperta F5 para executar o script completo.


/*******************************************************************************************************************************
--	Database que ser� utilizada para armazenar os dados dos Alertas. Se for necess�rio, altere para o nome desejado.
*******************************************************************************************************************************/
USE [Traces]

--------------------------------------------------------------------------------------------------------------------------------
--	Cria��o das tabelas de Controle dos Alertas
--------------------------------------------------------------------------------------------------------------------------------
use [Traces]

IF ( OBJECT_ID('[dbo].[Alerta]') IS NOT NULL )
	DROP TABLE [dbo].[Alerta]

CREATE TABLE [dbo].[Alerta] (
	[Id_Alerta]				INT IDENTITY PRIMARY KEY,
	[Id_Alerta_Parametro]	INT NOT NULL,
	[Ds_Mensagem]			VARCHAR(2000),
	[Fl_Tipo]				TINYINT,						-- 0: CLEAR / 1: ALERTA
	[Dt_Alerta]				DATETIME DEFAULT(GETDATE())
)

IF ( OBJECT_ID('[dbo].[Alerta_Parametro]') IS NOT NULL )
	DROP TABLE [dbo].[Alerta_Parametro]

CREATE TABLE [dbo].[Alerta_Parametro] (
	[Id_Alerta_Parametro] INT NOT NULL IDENTITY(1,1) PRIMARY KEY,
	[Nm_Alerta] VARCHAR(100) NOT NULL,
	[Nm_Procedure] VARCHAR(100) NOT NULL,
	[Fl_Clear] BIT NOT NULL,
	[Vl_Parametro] INT NULL,
	[Ds_Metrica] VARCHAR(50) NULL,
	[Ds_Email] VARCHAR(200) NULL
) ON [PRIMARY]

ALTER TABLE [dbo].[Alerta]
ADD CONSTRAINT FK01_Alerta
FOREIGN KEY ([Id_Alerta_Parametro])
REFERENCES [dbo].[Alerta_Parametro] ([Id_Alerta_Parametro])

--------------------------------------------------------------------------------------------------------------------------------
--	Insere os dados na tabela de Par�metro
--------------------------------------------------------------------------------------------------------------------------------
INSERT INTO [dbo].[Alerta_Parametro]([Nm_Alerta], [Nm_Procedure], [Fl_Clear], [Vl_Parametro], [Ds_Metrica], [Ds_Email]) 
VALUES	('Processo Bloqueado',				'stpAlerta_Processo_Bloqueado',				1,		2,		'Minutos',			@Ds_Email),
		('Arquivo de Log Full',				'stpAlerta_Arquivo_Log_Full',				1,		85,		'Percentual',		@Ds_Email),
		('Espaco Disco',					'stpAlerta_Espaco_Disco',					1,		80,		'Percentual',		@Ds_Email),
		('Consumo CPU',						'stpAlerta_Consumo_CPU',					1,		85,		'Percentual',		@Ds_Email),
		--('MaxSize Arquivo SQL',				'stpAlerta_MaxSize_Arquivo_SQL',			1,		15,		'Tamanho (MB)',		@Ds_Email),
		('Tempdb Utilizacao Arquivo MDF',	'stpAlerta_Tempdb_Utilizacao_Arquivo_MDF',	1,		70,		'Percentual',		@Ds_Email),
		('Conex�o SQL Server',				'stpAlerta_Conexao_SQLServer',				1,		2000,	'Quantidade',		@Ds_Email),
		('Status Database',					'stpAlerta_Erro_Banco_Dados',				1,		NULL,	NULL,				@Ds_Email),
		('P�gina Corrompida',				'stpAlerta_Erro_Banco_Dados',				0,		NULL,	NULL,				@Ds_Email),
		('Queries Demoradas',				'stpAlerta_Queries_Demoradas',				0,		100,	'Quantidade',		@Ds_Email),
		('Trace Queries Demoradas',			'stpCreate_Trace',							0,		3,		'Segundos',			@Ds_Email),
		('Job Falha',						'stpAlerta_Job_Falha',						0,		24,		'Horas',			@Ds_Email),
		('SQL Server Reiniciado',			'stpAlerta_SQL_Server_Reiniciado',			0,		20,		'Minutos',			@Ds_Email),
		('Database Criada',					'stpAlerta_Database_Criada',				0,		24,		'Horas',			@Ds_Email),
		('Database sem Backup',				'stpAlerta_Database_Sem_Backup',			0,		24,		'Horas',			@Ds_Email),
		('Banco de Dados Corrompido',		'stpAlerta_CheckDB',						0,		NULL,	NULL,				@Ds_Email),
		('Processos em Execu��o',			'stpEnvia_Email_Processos_Execucao',		0,		NULL,	NULL,				@Ds_Email)

-- Verifica o resultado da tabela com os parametros dos Alertas			
select * from [dbo].Alerta_Parametro

-- select * from [dbo].Alerta