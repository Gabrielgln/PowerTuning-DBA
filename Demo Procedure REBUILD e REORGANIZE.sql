USE [Traces]
GO
if object_id('stpManutencao_Indices') is not null
	drop procedure stpManutencao_Indices
GO

GO

/****** Object:  StoredProcedure [dbo].[stpManutencao_Indices]    Script Date: 09/18/2014 21:06:30 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE procedure [dbo].[stpManutencao_Indices] 
AS
BEGIN
	SET LOCK_TIMEOUT 300000 -- se ficar bloqueado por mais de 5 minutos, aborta.

	/***************************************************************************************************************************
	--	IMPORTANTE!!! Em ambientes muito grandes tem que fazer um controle para não estourar o LOG do banco de dados.
	***************************************************************************************************************************/

	DECLARE @Id INT, @SQLString NVARCHAR(1000)
				
	IF OBJECT_ID('tempdb..#Indices_Fragmentados') IS NOT NULL
		DROP TABLE #Indices_Fragmentados
		
	--	Seleciona os índices fragmentados
	SELECT  identity(int,1,1) Id,
		'ALTER INDEX ['+ Nm_Indice+ '] ON ' + Nm_Database+ '.'+Nm_Schema+'.['+ Nm_Tabela + 
		case when Avg_Fragmentation_In_Percent < 30 then '] REORGANIZE' else '] REBUILD' end Comando, -- Como existe janela para isso, sempre fazer rebuild
	 Page_Count, Nm_Database,Nm_Tabela,Nm_Indice, Fl_Compressao,Avg_Fragmentation_In_Percent
	INTO #Indices_Fragmentados
	FROM Traces.dbo.vwHistorico_Fragmentacao_Indice A WITH(NOLOCK) -- tabela que armazena o histórico de fragmentação
		join master.sys.databases B on B.name = A.Nm_Database
	WHERE Dt_Referencia >= CAST(FLOOR(cast(getdate() AS FLOAT)) AS DATETIME)
		and Avg_Fragmentation_In_Percent >= 10 
		and Page_Count > 1000
		and Nm_Indice is not null	
		and B.state_desc = 'ONLINE'
		
	-- select * from #Indices_Fragmentados
				
	WHILE exists (SELECT Id FROM #Indices_Fragmentados)
	BEGIN
		SELECT TOP 1 @Id = Id , @SQLString = Comando
		FROM #Indices_Fragmentados
		ORDER BY Nm_Database, Page_Count 
		
		-- Realiza o REORGANIZE OU O REBUILD
		EXECUTE sp_executesql @SQLString 			

		DELETE FROM #Indices_Fragmentados
		WHERE Id = @Id		
	END
END
