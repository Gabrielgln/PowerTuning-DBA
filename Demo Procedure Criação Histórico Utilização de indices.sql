/*******************************************************************************************************************************
(C) 2015, Fabrício Lima Soluções em Banco de Dados

Site: http://www.fabriciolima.net/

Feedback: contato@fabriciolima.net
*******************************************************************************************************************************/

use Traces

GO

--------------------------------------------------------------------------------------------------------------------------------
--	Criação da tabela para armazenar o histórico de utilização de índices
--------------------------------------------------------------------------------------------------------------------------------
if object_id('Historico_Utilizacao_Indices') is not null
	drop table Historico_Utilizacao_Indices
GO

CREATE TABLE [dbo].[Historico_Utilizacao_Indices](
[Id_Historico_Utilizacao_Indices] [int] IDENTITY(1,1) NOT NULL,
[Dt_Historico] [datetime] NULL,
[Id_Servidor] [smallint] NULL,
[Id_BaseDados] [smallint] NULL,
[Id_Tabela] [int] NULL,
[Nm_Indice] [varchar](1000) NULL,
[User_Seeks] [int] NULL,
[User_Scans] [int] NULL,
[User_Lookups] [int] NULL,
[User_Updates] [int] NULL,
[Ultimo_Acesso] [datetime] NULL
) ON [PRIMARY]

GO


--------------------------------------------------------------------------------------------------------------------------------
--	View para facilitar a visualização dos dados
--------------------------------------------------------------------------------------------------------------------------------
if object_id('vwHistorico_Utilizacao_Indice') is not null
	drop view vwHistorico_Utilizacao_Indice
GO
create view vwHistorico_Utilizacao_Indice
AS
select A.Dt_Historico, B.Nm_Servidor, C.Nm_Database,D.Nm_Tabela ,A.Nm_Indice, 
	A.User_Seeks, A.User_Scans, A.User_Lookups, A.User_Updates,A.Ultimo_Acesso
from Historico_Utilizacao_Indices A
	join Servidor B on A.Id_Servidor = B.Id_Servidor
	join BaseDados C on A.Id_BaseDados = C.Id_BaseDados
	join Tabela D on A.Id_Tabela = D.Id_Tabela

GO


--------------------------------------------------------------------------------------------------------------------------------
--	Procedure para popular a tabela criada
--------------------------------------------------------------------------------------------------------------------------------
if object_id('stpCarga_Utilizacao_Indice') is not null
	drop procedure stpCarga_Utilizacao_Indice

GO
CREATE procedure [dbo].[stpCarga_Utilizacao_Indice]
AS
BEGIN
	SET NOCOUNT ON
	 
	
	IF object_id('tempdb..##Historico_Utilizacao_Indices') IS NOT NULL DROP TABLE ##Historico_Utilizacao_Indices
	
	CREATE TABLE ##Historico_Utilizacao_Indices(
		[Id_Historico_Utilizacao_Indices] [int] IDENTITY(1,1) NOT NULL,
		[Dt_Historico] [datetime] NULL,
		[Nm_Servidor] [varchar](50) NULL,
		[Nm_Database] [varchar](100) NULL,
		[Nm_Tabela] [varchar](1000) NULL,
		[Nm_Indice] [varchar](1000) NULL,
		[User_Seeks] [int] NULL,
		[User_Scans] [int] NULL,
		[User_Lookups] [int] NULL,
		[User_Updates] [int] NULL,
		[Ultimo_Acesso] [datetime] NULL
	) ON [PRIMARY]

	EXEC sp_MSforeachdb 'Use ?; 
	insert into ##Historico_Utilizacao_Indices(Dt_Historico, [Nm_Servidor], [Nm_Database], [Nm_Tabela], [Nm_Indice], User_Seeks, User_Scans, User_Lookups, User_Updates, Ultimo_Acesso)
 	select getdate(), @@servername,DB_NAME(), o.Name,i.name, s.user_seeks,s.user_scans,s.user_lookups, s.user_Updates, 
		isnull(s.last_user_seek,isnull(s.last_user_scan,s.last_User_Lookup)) Ultimo_acesso
	from sys.dm_db_index_usage_stats s
		 join sys.indexes i on i.object_id = s.object_id and i.index_id = s.index_id
		 join sys.sysobjects o on i.object_id = o.id
	where s.database_id = db_id()
	order by o.Name, i.name, s.index_id'

    DELETE FROM ##Historico_Utilizacao_Indices
    WHERE Nm_Database IN ('master','msdb','tempdb','model')
    
    INSERT INTO Traces.dbo.Servidor(Nm_Servidor)
	SELECT DISTINCT A.Nm_Servidor 
	FROM ##Historico_Utilizacao_Indices A
		LEFT JOIN Traces.dbo.Servidor B ON A.Nm_Servidor = B.Nm_Servidor
	WHERE B.Nm_Servidor IS null
		
	INSERT INTO Traces.dbo.BaseDados(Nm_Database)
	SELECT DISTINCT A.Nm_Database 
	FROM ##Historico_Utilizacao_Indices A
		LEFT JOIN Traces.dbo.BaseDados B ON A.Nm_Database = B.Nm_Database
	WHERE B.Nm_Database IS null
	
	INSERT INTO Traces.dbo.Tabela(Nm_Tabela)
	SELECT DISTINCT A.Nm_Tabela 
	FROM ##Historico_Utilizacao_Indices A
		LEFT JOIN Traces.dbo.Tabela B ON A.Nm_Tabela = B.Nm_Tabela
	WHERE B.Nm_Tabela IS null	

    INSERT INTO Traces..Historico_Utilizacao_Indices(Dt_Historico, Id_Servidor, Id_BaseDados, Id_Tabela, Nm_Indice, User_Seeks, 
							User_Scans, User_Lookups, User_Updates, Ultimo_Acesso)	
    SELECT A.Dt_Historico, E.Id_Servidor, D.Id_BaseDados,C.Id_Tabela,A.Nm_Indice,A.User_Seeks,A.User_Scans,A.User_Lookups,A.User_Updates,A.Ultimo_Acesso 
    FROM ##Historico_Utilizacao_Indices A 
    	JOIN Traces.dbo.Tabela C ON A.Nm_Tabela = C.Nm_Tabela
		JOIN Traces.dbo.BaseDados D ON A.Nm_Database = D.Nm_Database
		JOIN Traces.dbo.Servidor E ON A.Nm_Servidor = E.Nm_Servidor 
    	LEFT JOIN Historico_Utilizacao_Indices B ON E.Id_Servidor = B.Id_Servidor AND D.Id_BaseDados = B.Id_BaseDados  
    													AND C.Id_Tabela = B.Id_Tabela AND A.Nm_Indice = B.Nm_Indice 
    													AND CONVERT(VARCHAR, A.Dt_Historico ,112) = CONVERT(VARCHAR, B.Dt_Historico ,112)
	WHERE A.Nm_Indice IS NOT NULL AND B.Id_Historico_Utilizacao_Indices IS NULL
    ORDER BY 2,3,4,5        			
end
GO