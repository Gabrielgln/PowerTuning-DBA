/*******************************************************************************************************************************
(C) 2015, Fabrício Lima Soluções em Banco de Dados

Site: http://www.fabriciolima.net/

Feedback: contato@fabriciolima.net
*******************************************************************************************************************************/

/*******************************************************************************************************************************
--	OBS:	Se optar por utilizar uma base com outro nome, fazer um replace em todo o script da palavra Traces para o nome da base desejada.
*******************************************************************************************************************************/

GO

USE Traces

if object_id('_Atualiza_Estatisticas') is not null
	drop table _Atualiza_Estatisticas
GO
create table _Atualiza_Estatisticas(
	Id_Estatistica int identity,
	Ds_Comando varchar(max),Nr_Linha int)
GO

if object_id('stpAtualiza_Estatisticas') is not null
	drop procedure stpAtualiza_Estatisticas
GO

CREATE procedure [dbo].[stpAtualiza_Estatisticas]
AS
	DECLARE @SQL VARCHAR(max)  
	DECLARE @DB sysname  

		DECLARE curDB CURSOR FORWARD_ONLY STATIC FOR  
	 SELECT [name]  
	   FROM master.sys.databases 
	   WHERE [name] NOT IN ('model', 'tempdb','master','msdb') 
	
		and state_desc = 'ONLINE'
	   ORDER BY [name] 
	         
		OPEN curDB  
	FETCH NEXT FROM curDB INTO @DB  
	WHILE @@FETCH_STATUS = 0  
	   BEGIN  
		   SELECT @SQL = 'USE [' + @DB +']' + CHAR(13) + 
			 '
			
			;WITH Tamanho_Tabelas AS (
					SELECT obj.Name, prt.rows
					FROM sys.objects obj
						JOIN sys.indexes idx on obj.object_id = idx.object_id
						JOIN sys.partitions prt on obj.object_id = prt.object_id
						JOIN sys.allocation_units alloc on alloc.container_id = prt.partition_id
					WHERE obj.type = ''U'' AND idx.index_id IN (0, 1) and prt.rows > 1000
					GROUP BY obj.Name, prt.rows )		
			    
			insert into Traces.._Atualiza_Estatisticas(Ds_Comando,Nr_Linha)	
			SELECT  ''UPDATE STATISTICS [' + @DB + '].'' + schema_Name(E.schema_id) + ''.['' +B.Name + ''] '' +  ''[''+A.Name+'']''+ '' WITH FULLSCAN'',D.rows
			FROM sys.stats A
				join sys.sysobjects B with(nolock) on A.object_id = B.id
				join sys.sysindexes C with(nolock) on C.id = B.id and A.Name = C.Name
				JOIN Tamanho_Tabelas D on  B.Name = D.Name 
				join sys.tables E on E.object_id = A.object_id
			WHERE  C.rowmodctr > D.rows*.02 -- Atualiza as estatísticas que tiveram mais de 2% de alterações.
				and C.rowmodctr > 100		-- Atualiza apenas quando tiver mais de 100 alterações. Evita atualizar tabelas pequenas
				and substring( B.Name,1,3) not in (''sys'',''dtp'')
				and substring(  B.Name , 1,1) <> ''_'' -- elimina tabelas teporárias		
			ORDER BY D.rows
				
		 '            
		   exec (@SQL )
	   --   select @SQL
			set @SQL = ''
	   
		   FETCH NEXT FROM curDB INTO @DB  
	   END  
	   
	CLOSE curDB  
	DEALLOCATE curDB	

 	declare @Loop int, @Comando nvarchar(4000)
	set @Loop = 1

	while exists(select top 1 null from _Atualiza_Estatisticas)
	begin	
		select top 1 @Comando = Ds_Comando,@Loop = Id_Estatistica
		from _Atualiza_Estatisticas
		--where Id_Estatistica = @Loop
		
		EXECUTE sp_executesql @Comando

		delete from _Atualiza_Estatisticas
		where Id_Estatistica = @Loop

		set @Loop = @Loop + 1		
	end
GO