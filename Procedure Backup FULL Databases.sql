--------------------------------------------------------------------------------------------------------------------------------
--	OBS: Lembrar de ALTERAR O caminho do Backup.
--------------------------------------------------------------------------------------------------------------------------------

use Traces

--	Exclui a procedure, caso já exista na database
if OBJECT_ID('stpBackup_FULL_Database') is not null
	drop procedure stpBackup_FULL_Database

--------------------------------------------------------------------------------------------------------------------------------
--	Cria a procedure
--------------------------------------------------------------------------------------------------------------------------------
GO
CREATE PROCEDURE [dbo].[stpBackup_FULL_Database] 
	@Caminho varchar(150) 
	, @Nm_Database varchar(50)
	, @Ds_Backup varchar(255) -- 255 é maior valor aceito pelo campo description da tabela 'msdb.dbo.backupset'
AS	

	backup database @Nm_Database 
	to disk = @Caminho
	WITH  INIT, CHECKSUM ,COMPRESSION  
	, NAME = @Caminho, Description = @Ds_Backup

GO


--	Exclui a procedure, caso já exista na database
if OBJECT_ID('stpBackup_Databases_Disco') is not null
	drop procedure stpBackup_Databases_Disco

--------------------------------------------------------------------------------------------------------------------------------
--	Cria a procedure
--------------------------------------------------------------------------------------------------------------------------------
GO
CREATE procedure [dbo].[stpBackup_Databases_Disco]
AS
	declare @Backup_Databases table (Nm_database varchar(500))
	declare @Nm_Database varchar(500), @Nm_Caminho varchar(5000)

	-- Busca todas as databases que estão ONLINE
	insert into @Backup_Databases
	select Name
	from sys.databases
	where	Name not in ('tempdb')		-- OBS: INCLUIR AQUI o nome das databases que serão desconsideras no Backup
			AND state_desc = 'ONLINE'		
	
	-- Loop para realizar o Backup FULL de cada database
	while exists (select null from @Backup_Databases)
	begin		
		select top 1 @Nm_Database = Nm_database from @Backup_Databases order by Nm_database
		
		/* -- Utilizado para armazenar UMA SEMANA de Backup FULL
		set @Nm_Caminho = 'C:\TEMP\' + @Nm_Database+ '_'+(CASE DATEPART(w, GETDATE()) 
						WHEN 1 THEN 'Domingo'
						WHEN 2 THEN 'Segunda'
						WHEN 3 THEN 'Terca'
						WHEN 4 THEN 'Quarta'
						WHEN 5 THEN 'Quinta' 
						WHEN 6 THEN 'Sexta'
						WHEN 7 THEN 'Sabado'
						END ) + '_Dados.bak'
		*/
		
		-- Utilizado para armazenar apenas UM Backup FULL
		set @Nm_Caminho = 'C:\TEMP\' + @Nm_Database + '_Dados.bak'
		
		-- Executa o Backup FULL
		exec Traces.dbo.stpBackup_Full_Database @Nm_Caminho, @Nm_Database, @Nm_Caminho -- O último parametro corresponde a descrição do Backup
		
		delete from @Backup_Databases where Nm_database = @Nm_Database
	End
GO