--------------------------------------------------------------------------------------------------------------------------------
--	1)	Script para verificar o caminho dos arquivos de dados e logs das databases
--------------------------------------------------------------------------------------------------------------------------------
select a.name, b.name as 'Logical filename', b.filename 
from sys.sysdatabases a 
	inner join sys.sysaltfiles b on a.dbid = b.dbid 
order by A.name


--------------------------------------------------------------------------------------------------------------------------------
--	2)	Procedure sp_whoisactive
--------------------------------------------------------------------------------------------------------------------------------
--	Abrir o código fonte da procedure "WHOISACTIVE" por curiosidade:
--	"..\Tarefas do dia a dia de um DBA\Modulo 06 - Tuning\Demo Procedure Whoisactive.sql"

--------------------------------------------------------------------------------------------------------------------------------
--	2.1)	Executar o comando abaixo em uma nova conexão no SSMS(executa por 10 minutos)
--------------------------------------------------------------------------------------------------------------------------------
waitfor delay  '00:10:00'

--------------------------------------------------------------------------------------------------------------------------------
--	2.2)	Executar os comandos abaixo em uma segunda conexão no SSMS
--------------------------------------------------------------------------------------------------------------------------------
if exists(select name from sys.databases where name = 'Treinamento_Modulo06')
	drop database Treinamento_Modulo06
GO
Create database Treinamento_Modulo06
GO
USE Treinamento_Modulo06

CREATE TABLE Teste_Lock (cod INT)

INSERT INTO Teste_Lock
SELECT 6

BEGIN TRAN
UPDATE Teste_Lock
SET cod = cod

-- EXECUTAR APENAS NO PASSO 2.6
-- ROLLBACK

--------------------------------------------------------------------------------------------------------------------------------	
--	2.3)	Executar os comandos abaixo em uma terceira conexão no SSMS
--------------------------------------------------------------------------------------------------------------------------------	
USE Treinamento_Modulo06

BEGIN TRAN
UPDATE Teste_Lock
SET cod = cod

-- EXECUTAR APENAS NO PASSO 2.6
-- ROLLBACK

--------------------------------------------------------------------------------------------------------------------------------
--	2.4)	Executar a procedure sp_whoisactive e analisar os resultados
--------------------------------------------------------------------------------------------------------------------------------
sp_whoisactive

--	Analisar a conexão que está com "WAITFOR" e as conexões envolvidas em um "Lock"

--	Analisar as colunas retornadas por essa procedure

--------------------------------------------------------------------------------------------------------------------------------
--	2.5) LOG Procedure sp_whoisactive
--------------------------------------------------------------------------------------------------------------------------------
-- Criar um job para monitorar o Whoisactive a cada minuto.
http://www.fabriciolima.net/blog/2016/03/17/queries-do-dia-a-dia-criando-um-log-de-historico-da-sp_whoisactive/

--Abrir e executar o script abaixo
--	"..\Tarefas do dia a dia de um DBA\Modulo 06 - Tuning\Demo Procedure Carga Whoisactive.sql"

--O Job DBA - Carga Whoisactive será criado. Executar manualmente simulando o agendamento desse JOB:
EXEC msdb.dbo.sp_start_job 'DBA - Carga Whoisactive'

--Conferindo a informação do log:
--Traces é a base onde estou guardando o log.
Select *
from Traces..Resultado_WhoisActive
order by Dt_log desc

-- finalizar as conexões abertas para esse teste

--------------------------------------------------------------------------------------------------------------------------------
--	2.6) Query similar a who is active, contudo, mais leve de executar.
--------------------------------------------------------------------------------------------------------------------------------
--	Para ser executada quando a whoisactive demora muito devido a problema de performance principalmente no TEMPDB
--	Essa só mostra as queries que estão em execução. Queries que estão com transações abertas mas não estão rodando nada, não são retornadas.

exec sp_whoisactive

use master
Go
select cast(DATEDIFF(HOUR,B.start_time,GETDATE())/86400 as varchar)+'d '
            +cast((DATEDIFF(SECOND,B.start_time,GETDATE())/3600)%24 as varchar)+'h '
             +cast((DATEDIFF(SECOND,B.start_time,GETDATE())/60)%60 as varchar)+'m '
             +cast(DATEDIFF(second,B.start_time,GETDATE())%60 as varchar)+'s' Duração
             , A.session_id as Sid, A.status, login_name
             , B.start_time, B.command
             , B.percent_complete
             , B.last_wait_type
             --, case (cast(B.last_wait_type as varchar) like 'LCK_M_X') then 
             , D.text
             , db_name(cast(B.database_id as varchar)) NmDB
             , C.last_read
             , C.last_write
             , program_name
             , login_time
from sys.dm_exec_sessions A 
             join sys.dm_exec_requests B on A.session_id = B.session_id
                           JOIN sys.dm_exec_connections C on B.session_id = C.session_id
                           CROSS APPLY sys.dm_exec_sql_text(C.most_recent_sql_handle) D 
where /*A.status = 'running' and */A.session_id > 50 and A.session_id <> @@spid
order by B.start_time

--------------------------------------------------------------------------------------------------------------------------------
--	2.7) Executar um rollback nas duas conexões que realizamos um update para teste
--------------------------------------------------------------------------------------------------------------------------------
--	ROLLBACK

--	Voltar aos slides

--------------------------------------------------------------------------------------------------------------------------------
--	3)	Criação de um Server Side Trace 
--------------------------------------------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------------------------------------------
--	3.1)	Criar um trace via tela para queries de 3 segundos. 
--------------------------------------------------------------------------------------------------------------------------------
--	Ir no menu "Tools" -> "SQL Server Profiler"

--	3.1.1) Conecte no seu SQL -> Na aba "Events Selection" deixe marcado apenas os eventos: "RPC:Completed" e "SQL:BatchCompleted" -> 

--	-> Para "RPC:Completed" marque a coluna TextData que fica desmarcada no evento "RPC:Completed"

--	3.1.2) Clique em "Column Filters" -> "Duration" -> "Greater than or Equal" -> Coloque o valor "3000" (está em milesegundos) -> 

--	-> Marque a opção "Exclude rows do not contain values" -> "OK" -> "RUN"

--	Pronto! O profile já está em execução!

--------------------------------------------------------------------------------------------------------------------------------
--	3.2)	Executar a query abaixo para aparecer no trace(roda por 4 segundos)
--------------------------------------------------------------------------------------------------------------------------------
waitfor delay '00:00:04'

--	Conferir na tela do profile a query

--------------------------------------------------------------------------------------------------------------------------------
--	3.3)	Conferindo os traces criados no banco de dados
--------------------------------------------------------------------------------------------------------------------------------
select * from fn_trace_getinfo (null)

--------------------------------------------------------------------------------------------------------------------------------
--	3.4)	Trace Default criado pelo SQL Server
--------------------------------------------------------------------------------------------------------------------------------
--	Script para "Habilitar" o Trace Default
EXEC sp_configure 'show advanced options', 1 
GO 
RECONFIGURE 
GO 
EXEC sp_configure 'default trace enabled', 1	-- 0 - Desabilita | 1 - Habilita 
GO 
RECONFIGURE 
GO 
EXEC sp_configure 'show advanced options', 0 
GO 
RECONFIGURE 

--	Conferindo
select * from fn_trace_getinfo (null)

--	Desabilitar?
--	R: Opcional. Eu costumava desabilitar, mas vi gente precisando dessa informação, então agora não desabilito mais.
--	https://www.simple-talk.com/sql/performance/the-default-trace-in-sql-server---the-power-of-performance-and-security-auditing/

--	Script para "Desabilitar" o Trace Default
EXEC sp_configure 'show advanced options', 1 
GO 
RECONFIGURE 
GO 
EXEC sp_configure 'default trace enabled', 0	-- 0 - Desabilita | 1 - Habilita 
GO 
RECONFIGURE 
GO 
EXEC sp_configure 'show advanced options', 0 
GO 
RECONFIGURE 

--	Conferindo
select * from fn_trace_getinfo (null)


/* Pulei para não embolar a cabeça dos iniciantes. Deixei aqui para quem quiser ver como gerar o script de criação de um trace.
--------------------------------------------------------------------------------------------------------------------------------
--	3.5)	Criando um "Server Side Trace"
--------------------------------------------------------------------------------------------------------------------------------
--	3.5.1)	Pare o Trace que você havia criado no passo 3.1 clicando no botão "Stop Selected Trace" no SQL Server Profiler. 

--	3.5.2)	No SQL Server Profiler, clique em "File" -> "Export" -> "Script Trace Definition" -> "For SQL Server 2005 - SQL11..." -> 
--			-> Salve o arquivo e visualize o código gerado
*/


--------------------------------------------------------------------------------------------------------------------------------
--	3.6)	Criando um "Server Side Trace" para queries que demoram mais de três segundos
--------------------------------------------------------------------------------------------------------------------------------
--	Criar a procedure de Trace
--	Abrir: "\Tarefas do dia a dia de um DBA\Modulo 06 - Tuning\Demo Procedure Criação do Trace.sql"

--	Executar a procedure criada
EXEC Traces.dbo.stpCreate_Trace

--	Conferir o trace criado
select * from fn_trace_getinfo (null)

--	3.6.1)	Fluxo de manutenção do trace de queries demoradas para pegar os dados do Trace e mandar para a tabela Traces.
--	1 - Desabilita o Trace
--	2 - Pega os dados do arquivo e envia para a tabela Traces
--	3 - Deleta o arquivo
--	4 - Recria o trace e o arquivo

--	Criar o job de Trace e olhar os steps para entender o que ele faz.
--	Abrir: \Tarefas do dia a dia de um DBA\Modulo 06 - Tuning\Demo Job Trace.sql

--------------------------------------------------------------------------------------------------------------------------------
--	3.7)	Testar o Trace
--------------------------------------------------------------------------------------------------------------------------------
waitfor delay '00:00:04'

--	Rodar o Job
EXEC msdb.dbo.sp_start_job 'DBA - Trace Banco de Dados'

--	Validar se o Trace pegou essa query
Select * from Traces..Traces

--------------------------------------------------------------------------------------------------------------------------------
--	3.8)	Olhar o arquivo de Trace que foi criado na pasta: "C:\Fabricio\SQL Server\Treinamento"
--------------------------------------------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------------------------------------------
--	3.9)	Relembrando o Fluxo do Trace:
--------------------------------------------------------------------------------------------------------------------------------
--	1 - Desabilita o Trace
--	2 - Pega os dados do arquivo e envia para a tabela Traces
--	3 - Deleta o arquivo
--	4 - Recria o trace e o arquivo


--------------------------------------------------------------------------------------------------------------------------------
--	4)	Criação de uma rotina para logar Contadores no SQL Server 
--------------------------------------------------------------------------------------------------------------------------------
--	4.1)	Abrir o código abaixo e executar a criação da tabela e da procedure para coletar essa informação
--	Criar as tabelas e a procedure
--	Abrir "..\Tarefas do dia a dia de um DBA\Modulo 06 - Tuning\Demo Procedure Criação Log Contadores.sql"
 
--	4.2)	Executar a procedure de carga dos Contadores criada no passo anterior
exec Traces.dbo.stpCarga_ContadoresSQL

SELECT Nm_Contador,Dt_Log,Valor
FROM Traces..Contador A 
	JOIN Traces..Registro_Contador B ON A.Id_Contador = B.Id_Contador
ORDER BY 1,2

--	4.3)	Agora é só criar um JOB para rodar essa procedure a cada 1 minuto.
--	Dever de casa para quem ainda não tinha trabalhado com JOB no SQL.
 

--------------------------------------------------------------------------------------------------------------------------------
--	5)	Estatísticas
--------------------------------------------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------------------------------------------
--	5.1)	Visualizando as estatísticas de uma tabela
--------------------------------------------------------------------------------------------------------------------------------
--	5.1.2)	Criação da tabela

--	Executar essas duas queries para criar duas estatísticas
use TreinamentoDBA

--	Criação de uma tabela para os testes
if object_id('Empregado') is not null
	drop table Empregado

CREATE TABLE Empregado( 
	Id_Empregado int identity,
	Nome VARCHAR(50) NOT NULL,
	Salario numeric(9,2),
	Fl_Estado_Civil tinyint,	-- 1 - Solteiro; 2 - Casado
)

--	Inserindo registros na tabela
insert into Empregado (Nome, Salario, Fl_Estado_Civil)
select 'Fabricio Lima', 675, 2

insert into Empregado (Nome, Salario, Fl_Estado_Civil)
select 'Chefe do Fabricio Lima', 30000, 1

insert into Empregado (Nome, Salario, Fl_Estado_Civil)
select 'Joselito Estagiário', 100, 2

insert into Empregado (Nome, Salario, Fl_Estado_Civil)
select 'Hidráulico Oliveira', 1000, 1

--	5.1.3)	Analisar as estatísticas da tabela criada no Object Explorer
--	Expanda a database -> "Tables" -> "Empregado" -> "Statistics"

--	Como a tabela foi criada e nenhuma consulta foi realizada, não existe nenhuma estatística para essa tabela.

--	5.1.4)	Realizar consultas para criar estatísticas

--	Realizando duas consultas 
Select *
from Empregado
where Id_Empregado = 1

Select *
from Empregado
where Nome = 'Hidráulico Oliveira'

--	Agora clique em "Statiscs" com o botão direito e clique em "Refresh".

--	Como pode ser visto, o default das bases é ter o "auto create statistics" habilitado.
--	Dessa forma, quando realizamos uma consulta o SQL cria as estatísticas, caso ainda não exista.

--	Excluir as estatisticas (pegar nome atual da estatistica)
DROP STATISTICS Empregado._WA_Sys_00000001_070CFC19
DROP STATISTICS Empregado._WA_Sys_00000002_1B0907CE

--	Agora clique em "Statiscs" com o botão direito e clique em "Refresh" para conferir se foram excluídas.

--	5.1.5) Criando estatísticas a partir de índices

--	Criar um índice e conferir as estatisticas
create nonclustered index SK01_Empregado on Empregado(Id_Empregado)

--	Agora clique em "Statiscs" com o botão direito e clique em "Refresh" para conferir se ela foi criada.

--	Excluindo o indice que foi criado. Verificar depois se a estatistica foi excluída
drop index Empregado.SK01_Empregado

--------------------------------------------------------------------------------------------------------------------------------
--	5.2)	Analisando as informações das estatísticas
--------------------------------------------------------------------------------------------------------------------------------
use TreinamentoDBA

Select *
from Empregado
where Id_Empregado = 1

Select *
from Empregado
where Nome = 'Hidráulico Oliveira'

Select * from Empregado

--	Confere as estatisticas da coluna Nome
DBCC SHOW_STATISTICS('Empregado','_WA_Sys_00000002_070CFC19')
WITH HISTOGRAM

--	Explicação das colunas do comando acima
--	RANGE_HI_KEY -	É o último valor do range de valores da estatística. No caso do RANGE 'Chefe do Fabricio Lima' seriam nomes de A à C.

--	RANGE_ROWS -    É o número de registros presentes nesse range exceto o RANGE_HI_KEY. No caso do RANGE 'Chefe do Fabricio Lima', 
--					seria todos os nomes de A à C, exceto o 'Chefe do Fabricio Lima'. Como não tem nenhum, é zero. 

--	EQ_ROWS -   É a quantidade de registros iguais ao RANGE_HI_KEY. No caso do RANGE 'Chefe do Fabricio Lima', 
--				como só tem um registro igual a esse, o valor é 1.

--	DISTINCT_RANGE_ROWS -   É o número de registros distintos, mas não conta o RANGE_HI_KEY. No caso do RANGE 'Chefe do Fabricio Lima', 
--							como não tem outro registro, o valor é 0.

--	AVG_RANGE_ROWS -	É a média de números duplicados, mas não iguais ao RANGE_HI_KEY. É calculado como RANGE_ROWS / DISTINCT_RANGE_ROWS.

--	Insere registros para alterar as estatísticas
insert into Empregado (Nome,Salario,Fl_Estado_Civil)
select 'Antonio AAAA', 1000, 1
Go 3

insert into Empregado (Nome, Salario, Fl_Estado_Civil)
select 'Antonio BBB', 1000, 1
Go 3

insert into Empregado (Nome, Salario, Fl_Estado_Civil)
select 'Antonio CCC', 1000, 1

--	Confere as estatisticas da coluna Nome
DBCC SHOW_STATISTICS('Empregado','_WA_Sys_00000002_070CFC19')
WITH HISTOGRAM

--	Atualiza as estatísticas
UPDATE STATISTICS Empregado WITH FULLSCAN 

Select * from Empregado

--	Confere os valores atualizados
DBCC SHOW_STATISTICS('Empregado','_WA_Sys_00000002_070CFC19')
WITH HISTOGRAM

--	Analisando as estatisticas do campo Id_Empregado
DBCC SHOW_STATISTICS('Empregado','_WA_Sys_00000001_070CFC19')
WITH HISTOGRAM

SET IDENTITY_INSERT Empregado ON -- Comando para conseguir inserir um valor em uma coluna identity

insert into Empregado (Id_Empregado, Nome, Salario, Fl_Estado_Civil)
select 5,'Antonio CCC', 1000, 1
GO 5

SET IDENTITY_INSERT Empregado OFF

--	Analisando as estatisticas do campo Id_Empregado
DBCC SHOW_STATISTICS('Empregado','_WA_Sys_00000001_070CFC19')
WITH HISTOGRAM

--	Atualiza as estatísticas
UPDATE STATISTICS Empregado WITH FULLSCAN 

DBCC SHOW_STATISTICS('Empregado','_WA_Sys_00000001_070CFC19')
WITH HISTOGRAM

Select * from Empregado

--------------------------------------------------------------------------------------------------------------------------------
--	5.3) Atualização automáticas de estatísticas
--------------------------------------------------------------------------------------------------------------------------------
--	Vimos a importância de se atualizar a estatísticas para o SQL Server conhecer o padrão dos dados que compõem os registros de uma tabela.

--	Como o SQL Server atualiza as estatísticas de uma tabela:

--	Se a tabela tiver mais de 500 registros (praticamente todas), as estatísticas dessa tabela só serão atualizadas quando tivermos: 

-- (500 + 20% do tamanho da tabela) de alterações na tabela

--	O pior é que isso pode acontecer no meio do dia gerando um custo no seu ambiente de produção.

--	Imagina uma tabela de 70 milhões de registros, se eu fosse esperar as estatísticas serem atualizadas automaticamente, 
--	desconsiderando as estatísticas de índices que são atualizadas por exemplo com um REBUILD, minhas estatísticas seriam atualizadas quando eu tivesse:

-- (500 + 20% * 70.000.000 = 14.000.500) de alterações.
	
--	14 milhões de alterações para alterar as estatísticas. Esse tempo é muito alto e elas ainda poderiam ser atualizadas durante o dia.

--	Como resolver?

--	Criando uma rotina para atualizar suas estatísticas fora do horário de expediente.

--	Query que mostra as alterações nas colunas participantes das estatísticas
WITH Tamanho_Tabelas AS (
SELECT obj.name, prt.rows
FROM sys.objects obj
JOIN sys.indexes idx on obj.object_id= idx.object_id
JOIN sys.partitions prt on obj.object_id= prt.object_id
JOIN sys.allocation_units alloc on alloc.container_id= prt.partition_id
WHERE obj.type= 'U' AND idx.index_id IN (0, 1) --and prt.rows> 1000
GROUP BY obj.name, prt.rows)

SELECT A.name, B.name, C.rowmodctr
FROM sys.stats A
join sys.sysobjects B on A.object_id = B.id
join sys.sysindexes C on C.id = B.id and A.name= C.Name
JOIN Tamanho_Tabelas D on  B.name= D.Name
WHERE	substring( B.name,1,3) not in ('sys','dtp')
		and B.name = 'Empregado'
		--and C.rowmodctr > 100
		--and C.rowmodctr> D.rows*.005
ORDER BY D.rows

--	Essa alteração só muda as estatísticas da coluna NomeCliente
update Empregado
set Nome = 'Antonio DDD'
where Nome = 'Antonio CCC'

--	Essa muda as estatísticas de todas as colunas da tabela
delete Empregado
where Id_Empregado = 4

--	Executar a query que mostra as alterações das estatísticas novamente para conferir que ela realmente teve alteração.

--------------------------------------------------------------------------------------------------------------------------------
--	5.4) Rotina para atualização de estatísticas de todas as bases de um servidor.
--------------------------------------------------------------------------------------------------------------------------------
--	Abrir a procedure
--	"..\Tarefas do dia a dia de um DBA\Modulo 06 - Tuning\Demo Procedure Atualizacao de Estatisticas.sql"

--	Em seguida é só agendar um job em um horário de pouco movimento do seu servidor. 

--	Recomendo a leitura desse meu post no Blog que detalha essa rotina de update de estatísticas
--	http://www.fabriciolima.net/blog/2011/06/29/rotina-para-atualizar-as-estatisticas-do-seu-banco-de-dados/


--------------------------------------------------------------------------------------------------------------------------------
--	6)	Indices
--------------------------------------------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------------------------------------------
--	6.1)	INDICE CLUSTERED
--------------------------------------------------------------------------------------------------------------------------------
--	Criação da tabela e do índice clustered através da primary key
if object_id('TestesIndices') is not null 
	drop table TestesIndices

create table TestesIndices(
	Cod int,
	Data datetime default(getdate()),
	Descricao varchar(1000)
)

--	Script para criar um índice clustered caso ele não exista
create clustered index SK01_TestesIndices on TestesIndices(Cod) with(FILLFACTOR = 95)

--	Lembrando que quando criamos uma PRIMARY key em uma tabela, ela automaticamente cria um índice clustered
--	Selecione o nome da tabela e apert ALT + F1 para conferir o índice criado.

--	Comando par anão aparecer mensagens de escritas na aba messages
SET NOCOUNT ON

--	Populando a tabela com 100 mil registros (1 minuto)
insert into TestesIndices(Cod,Descricao)
select cast(1000000000*rand()/1000 as int),replicate('0',1000)
GO 100000

--	Faça um select na tabela para comferir os dados inseridos
select count(*) from TestesIndices

--	CTRL+L - Mostra o execution plan estimado da query
--	CTRL+M - Mostra o execution plan real da query

--	Em alguns casos bem específicos, eles podem ser diferentes. Principalmente em ambientes sem atualização de estatísticas.

--	Segue referencia abaixo:
--	http://www.brentozar.com/archive/2014/07/comparing-estimated-actual-execution-plans-sql-server/

--	Execute um CTRL+M para que possamos ver o execution plan utilizado por uma query e depois rode a query abaixo
select *
from TestesIndices
where Cod = 18

--	O SQL fez um índice Seek. Ou seja, ele utilizou a árvore B-Tree do índice para encontrar a coluna Cod

--	Comandos que retornam informações do consumo de recursos de uma query. Utilizo MUITO para fazer tuning.
set statistics io on


--	Referência set statistics IO: http://www.practicalsqldba.com/2013/07/sql-server-performance-tuning.html
-- http://statisticsparser.com/

--	Agora faça um select pela data
select *
from TestesIndices
where Data = '2016-04-25 20:38:00.820'

--	O SQL fez um Scan em toda a tabela porque não existe um índice nessa coluna para ele descer a árvore e encontrar o resultado.
--	Como o índice clustered é a própria tabela, ele faz um CLustered Index Scan.

--	Consumo da query


--------------------------------------------------------------------------------------------------------------------------------
--	6.2)	INDICE NONCLUSTERED
--------------------------------------------------------------------------------------------------------------------------------
--	Criação de um índice nonclustered na coluna Data
drop index TestesIndices.SK02_TestesIndices 
create nonclustered index SK02_TestesIndices on TestesIndices(Data)  with(FILLFACTOR=90) 

TIRAR ESPAÇO SOBRANDO:
alter index SK02_TestesIndices on TestesIndices REBUILD

--	Realizando a mesma consulta com filtro na coluna Data
select * 
from TestesIndices
where data = '2016-04-25 20:38:00.820'

--	Nesse caso o SQL Server fez um Index Seek no indice SK02, contudo, como eu fiz um select *, esse índice não tem a coluna Descricao.
--	Quando isso acontece o SQL Server tem que ir no índice clustered buscar a informação dessa coluna
--	Para isso ele usa um Key Lookup. Para cada registro retornado no Index Seek ele faz uma busca no indice clustered para pegar a coluna Descrição
--	Para uma consulta que retorna muitos registros, essa operação se torna bem custosa.

--	Consumo da query


--	Agora vamos criar um índice nonclustered e incluir a coluna Descricao nesse índice
create nonclustered index SK03_TestesIndices on TestesIndices(Data) INCLUDE(Descricao) with(FILLFACTOR=90) 

-----Pausa rápida -----
--Infelizmente o ALT+F1 não mostram os índices com include.
-- Você pode utilizar a consulta abaixo para ver os índices com include:
select SCHEMA_NAME (o.SCHEMA_ID) SchemaName
  ,o.name ObjectName,i.name IndexName
  ,i.type_desc
  ,LEFT(list, ISNULL(splitter-1,len(list)))Columns
  , SUBSTRING(list, indCol.splitter+1, 1000) includedColumns--len(name) - splitter-1) columns
  , COUNT(1)over (partition by o.object_id)
from sys.indexes i
join sys.objects o on i.object_id= o.object_id
cross apply (select NULLIF(charindex('|',indexCols.list),0) splitter , list
             from (select cast((
                          select case when sc.is_included_column = 1 and sc.ColPos= 1 then'|'else '' end +
                                 case when sc.ColPos > 1 then ', ' else ''end + name
                            from (select sc.is_included_column, index_column_id, name
                                       , ROW_NUMBER()over (partition by sc.is_included_column
                                                            order by sc.index_column_id)ColPos
                                   from sys.index_columns  sc
                                   join sys.columns        c on sc.object_id= c.object_id
                                                            and sc.column_id = c.column_id
                                  where sc.index_id= i.index_id
                                    and sc.object_id= i.object_id) sc
                   order by sc.is_included_column
                           ,ColPos
                     for xml path (''),type) as varchar(max)) list)indexCols) indCol
where indCol.splitter is not null
order by SchemaName, ObjectName, IndexName
-----Fim da Pausa -----

--	Realizando a mesma consulta para ver se o novo indice será utilizado
select * 
from TestesIndices
where data = '2016-04-25 20:38:00.820' -- utilizar a mesma data do teste anterior

--	Agora o SQL volta a fazer um Index Seek porque todas as colunas que ele precisa estão no índice SK03.

--	Consumo da query sem a necessidade de fazer o lookup no índice clustered


--	Tamanho dos índices
SELECT i.[name] AS IndexName
    ,SUM(s.[used_page_count]) * 8 AS IndexSizeKB
FROM sys.dm_db_partition_stats AS s
INNER JOIN sys.indexes AS i ON s.[object_id] = i.[object_id]
    AND s.[index_id] = i.[index_id]
	join sysobjects o ON i.[object_id] = o .id
where o.name = 'TestesIndices'
GROUP BY i.[name]
ORDER BY 2 desc

--	Indice 1 - Clustered (Cod, Data e Descrição) - 3 colunas
--  Indice 3 - NonClustered (Data , Descrição e Cod) - 3 colunas

-- Porque o índice 1 está muito maior que o 3??????



































--	O índice SK01_TestesIndices está maior que o 3 porque ele está fragmentado.

--	Desfragmente esse índice e olhe os tamanhos novamente
ALTER INDEX SK01_TestesIndices on TestesIndices REBUILD

--------------------------------------------------------------------------------------------------------------------------------
--	6.3)	Tabela sem Indice Clustered
--------------------------------------------------------------------------------------------------------------------------------
if object_id('TestesIndices') is not null 
	drop table TestesIndices

create table TestesIndices
(Cod int  ,
Data datetime default(getdate()),
Descricao varchar(1000))

--	Retirar o CTRL + M para fazer esse insert. Caso contrário vai demorar muito
set statistics io OFF


insert into TestesIndices(Cod,Descricao)
select cast(1000000000*rand()/1000 as int),replicate('0',500)
GO 50000

set statistics io On

--	INDICE NONCLUSTERED
create nonclustered index SK01_TestesIndices on TestesIndices(Data) INCLUDE(Descricao) with(FILLFACTOR=90) 

--	Dar um CRTL+M novamente para ver os planos de execuções das queries
select * 
from TestesIndices  
where data = '2016-04-25 20:41:45.743'

--	Agora o SQL faz um Seek no indice nonclustered e depois faz um RID Lookup na Heap.

--	Realizando um select na tabela Cod que ainda não tem índice
select * 
from TestesIndices  
where cod = 60861

--	O SQL faz um Table Scan e ainda sugere a criação de um índice para você. Vamos falar dessa sugestão daqui a pouco.

--	Consumo da query com o Table Scan

--	Criando um índice nonclustered na coluna Cod. Repare que a tabela continua sem índice CLustered
CREATE NONCLUSTERED INDEX SK02_TestesIndices ON [dbo].[TestesIndices] ([Cod]) WITH(FILLFACTOR=95)

--	Consultando novamente
select * 
from TestesIndices  
where cod = 212613

--	Consumo depois da criação do índice na coluna Cod


---------------- Comparação SCAN x SEEK -------------------
-- Escolher um código existente e fazer um insert de 20 mil linhas dele
INSERT INTO TestesIndices(Cod,Data,Descricao)
SELECT TOP 20000 212613 , Data, Descricao
from TestesIndices  


--	Consulta básica por um cod e tenho índice no cod
select * 
from TestesIndices  
where cod = 212613












-- SQL seu burro, sou mais esperto que voce!! #tomabesta
select * 
from TestesIndices WITH(INDEX=SK02_TestesIndices)  
where cod = 212613


-- Voltar aos slides


--------------------------------------------------------------------------------------------------------------------------------
--		INCLUDE (novo)
--------------------------------------------------------------------------------------------------------------------------------
--Exclui todos os indices da tabela
DROP INDEX TestesIndices.SK01_TestesIndices
DROP INDEX TestesIndices.SK02_TestesIndices

insert into TestesIndices(Cod,Descricao)
select cast(1000000000*rand()/1000 as int),replicate('0',500)
GO 100000

ALTER TABLE TestesIndices ADD SimulandoVariasColunasNoInclude VARCHAR(100) 


UPDATE  TestesIndices
SET SimulandoVariasColunasNoInclude = REPLICATE('0',100)


create nonclustered index SK01_TestesIndices on TestesIndices(Data) INCLUDE(SimulandoVariasColunasNoInclude) with(FILLFACTOR=95) 
create nonclustered index SK02_TestesIndices on TestesIndices(Data,SimulandoVariasColunasNoInclude) with(FILLFACTOR=95) 

REBUILD NO FILLFACTOR:
REBUILD WITH FILLFACTOR = 90%

SELECT ISNULL(i.[name],'HEAP') AS IndexName
    ,SUM(s.[used_page_count]) * 8 AS IndexSizeKB
FROM sys.dm_db_partition_stats AS s
INNER JOIN sys.indexes AS i ON s.[object_id] = i.[object_id]
    AND s.[index_id] = i.[index_id]
	join sysobjects o ON i.[object_id] = o .id
where o.name = 'TestesIndices'
GROUP BY i.[name]
ORDER BY 2 DESC

SELECT 22176*1.00/2212212

SET STATISTICS IO ON

-- Fazendo um seek
select Data,SimulandoVariasColunasNoInclude
FROM TestesIndices WITH(INDEX=SK01_TestesIndices)
where data = '2017-06-24 10:29:14.817'

select Data,SimulandoVariasColunasNoInclude
FROM TestesIndices WITH(INDEX=SK02_TestesIndices)
where data = '2017-06-24 10:29:14.817'

--Fazendo um scan
select Data,SimulandoVariasColunasNoInclude
FROM TestesIndices WITH(INDEX=SK01_TestesIndices)

select Data,SimulandoVariasColunasNoInclude
FROM TestesIndices WITH(INDEX=SK02_TestesIndices)

-- Mesmo teste, mas agora com a coluna Descrição = varchar(1000)
create nonclustered index SK03_TestesIndices on TestesIndices(Data) INCLUDE(Descricao) with(FILLFACTOR=95) 
create nonclustered index SK04_TestesIndices on TestesIndices(Data,Descricao) with(FILLFACTOR=95) 

SELECT i.[name] AS IndexName
    ,SUM(s.[used_page_count]) * 8 AS IndexSizeKB
FROM sys.dm_db_partition_stats AS s
INNER JOIN sys.indexes AS i ON s.[object_id] = i.[object_id]
    AND s.[index_id] = i.[index_id]
	join sysobjects o ON i.[object_id] = o .id
where o.name = 'TestesIndices'
GROUP BY i.[name]
ORDER BY 2 DESC

SELECT 91096*1.00/97872

SET STATISTICS IO ON

-- Fazendo um seek
select Data,Descricao
FROM TestesIndices WITH(INDEX=SK03_TestesIndices)
where data = '2017-06-24 10:29:14.817'

select Data,Descricao
FROM TestesIndices WITH(INDEX=SK04_TestesIndices)
where data = '2017-06-24 10:29:14.817'

-- Fazendo um Scan
select Data,Descricao
FROM TestesIndices WITH(INDEX=SK03_TestesIndices)

select Data,Descricao
FROM TestesIndices WITH(INDEX=SK04_TestesIndices)

-- SET STATISTICS IO OFF
-- CTRL+M
--Voltar para os slides

--------------------------------------------------------------------------------------------------------------------------------
--	6.4)	Fragmentacao de índices
--------------------------------------------------------------------------------------------------------------------------------
--	6.4.1)  Rotina de log da Fragmentação de índices

--	Abrir o script e executar para criar as estruturas de log de Fragmentação de índices
--	..\\Tarefas do dia a dia de um DBA\Modulo 06 - Tuning\Demo Procedure Carga Fragmentacao de Indice.sql

--	Tabelas vazias ainda
select *
from Traces..vwHistorico_Fragmentacao_Indice
order by avg_fragmentation_in_percent desc

--	Executar a procedure que acabamos de criar e que guarda as informações de fragmentação de índices nas tabelas 
exec Traces..stpCarga_Fragmentacao_Indice

--	Coloquem essa procedure em um Job no servidor

--	View onde vemos as informações dos índices fragmentados
select *
from Traces..vwHistorico_Fragmentacao_Indice
where Page_count > 1000
order by avg_fragmentation_in_percent desc

/******************************************************************************************************************************
--	Informações importantes dessa rotina de fragmentação de índices:
--	É com essas informações que crio minha rotina de REBUILD e REORGANIZE
--	Com essas informações diárias, conseguimos validar se um índice está se fragmentando muito rapidamente 
	e analisar uma possível alteração do FILLFACTOR desse índice.
*******************************************************************************************************************************/

-- 6.4.2)	REBUILD x REORGANIZE

--	Criação de uma tabela para testes
if object_id('TestesIndices') is not null 
	drop table TestesIndices

create table TestesIndices(
	Cod int  ,
	Data datetime default(getdate()),
	Descricao varchar(1000)
)

--	Criação de um INDICE CLUSTERED 
create clustered index SK01_TestesIndices on TestesIndices(Cod) with(FILLFACTOR=95)

--	Criação de um INDICE NONCLUSTERED
create nonclustered index SK02_TestesIndices on TestesIndices(Data) INCLUDE(Descricao) with(FILLFACTOR=90) 

--	Realizando um insert de 20 mil linhas
insert into TestesIndices(Cod,Descricao)
select cast(1000000000*rand()/1000 as int),replicate('0',500)
GO 20000

--	Query para verificar a fragmentação de índices
SELECT index_Type_desc,avg_page_space_used_in_percent
	,avg_fragmentation_in_percent	
	,index_level
	,record_count
	,page_count
	,fragment_count
	,avg_record_size_in_bytes
FROM sys.dm_db_index_physical_stats(DB_ID('TreinamentoDBA'),OBJECT_ID('TestesIndices'),NULL,NULL,'DETAILED')

/******************************************************************************************************************************
Onde:
	TreinamentoDBA: Database analisada
	TestesIndices: Tabela analisada

	Basta alterar esses parâmetros para testar no seu ambiente. Não execute durante o dia para tabelas muito grandes pois pode demorar.
*******************************************************************************************************************************/
GO

--	Executar um REORGANIZE do índice SK01 e conferir a fragmentação dos índices
ALTER INDEX SK01_TestesIndices ON TestesIndices REORGANIZE

--	Executar um REBUILD do índice SK01 e conferir a fragmentação dos índices
ALTER INDEX SK01_TestesIndices ON TestesIndices REBUILD

--	Executar um REBUILD do índice SK02 e conferir a fragmentação dos índices
ALTER INDEX SK02_TestesIndices ON TestesIndices REBUILD

--	Abrir a procedure de REBUILD e REORGANIZE
--	..\\Tarefas do dia a dia de um DBA\Modulo 06 - Tuning\Demo Procedure REBUILD e REORGANIZE.sql

--	Coloque essa procedure de REBUILD em um job diário no servidor
GO


/******************************************************************************************************************************
--	Voltar para os slides
*******************************************************************************************************************************/

--------------------------------------------------------------------------------------------------------------------------------
--	6.5)	Monitorando a utilização dos índices no SQL Server
--------------------------------------------------------------------------------------------------------------------------------
--	Dica de Tuning.
--	Analisar as maiores tabelas do ambiente e validar se os índices delas estão sendo utilizados.

--	Essa query mostra a atualização dos índices desde a última vez que o SQL Server foi reiniciado. Como ainda não rodei nenhuma query, está vazia.
select getdate(), o.Name,i.name, s.user_seeks,s.user_scans,s.user_lookups, s.user_Updates, 
	isnull(s.last_user_seek,isnull(s.last_user_scan,s.last_User_Lookup)) Ultimo_acesso,fill_factor
from sys.dm_db_index_usage_stats s
	 join sys.indexes i on i.object_id = s.object_id and i.index_id = s.index_id
	 join sys.sysobjects o on i.object_id = o.id
where s.database_id = db_id() and o.name in ('TestesIndices') --and i.name = 'SK02_Telefone_Cliente'
order by s.user_seeks + s.user_scans + s.user_lookups desc

--	Última vez que o SQL Server foi reiniciado
select * from sys.databases where database_id = 2

--	Realizar o select abaixo e validar novamente a utilização de índices
--	Habilite o ctrl+M para ver o que o SQL está fazendo.
Select *
from TestesIndices

--	Agora vimos que o SQL realizou um scan no índice SK01_TestesIndices

--	Realizar o select abaixo e validar novamente a utilização de índices.
select *
from TestesIndices
where cod = 1

--	Agora vimos que o SQL realizou um seek  no índice SK01_TestesIndices

--	Realizar o select abaixo e validar novamente a utilização de índices
select *
from TestesIndices
where Data = getdate()

--	Agora vimos que o SQL realizou um seek  no índice SK01_TestesIndices

--	Realizar um update em todos os registros dessa tabela e validar novamente a utilização de índices
update TestesIndices
set Data = Data

--	Agora vimos que o SQL realizou uma operação de update nos dois índices.

--	Criação de uma rotina para armazenar a utilização dos índices por dia
--	Abrir o script abaixo e executar os comandos de criação
--	..\\Tarefas do dia a dia de um DBA\Modulo 06 - Tuning\Demo Procedure Criação Histórico Utilização de indices.sql

--	Execução da procedure para popular as tabelas com os dados de utilizção de índices
--	retirar o CTRL+M para não demorar
exec traces..stpCarga_Utilizacao_Indice

--	Segue o resultado
select * 
from Traces..vwHistorico_Utilizacao_Indice
where Nm_Tabela = 'TestesIndices'
order by User_Seeks+User_Scans+User_Lookups desc

--	Coloquem essa procedure em um job diário. Dessa forma se o SQL Server for reiniciado, você consegue saber 
--	como estava a utilização desse índice antes dele reiniciar.

--------------------------------------------------------------------------------------------------------------------------------
--	6.6)	Dicas para a criação de índices
--------------------------------------------------------------------------------------------------------------------------------
if object_id('TestesIndices') is not null 
	drop table TestesIndices

create table TestesIndices(
	Cod int  ,
	Data datetime default(getdate()),
	Descricao varchar(1000)
)

SET NOCOUNT ON
SET STATISTICS IO OFF

--retirar o CTRL M
--	Populando a tabela com 100 mil registros (1 minuto)
insert into TestesIndices(Cod,Descricao)
select cast(1000000000*rand()/1000 as int),replicate('0',1000)
GO 100000

--	Habilite o CTRL + M
select *
from TestesIndices
where Data = '2016-04-25 21:22:43.460'

select * 
from TestesIndices  
where cod = 543028

--	Query que mostra algumas sugestão de índices para que possamos analisar a criação
SELECT 
dm_mid.database_id AS DatabaseID,
dm_migs.avg_user_impact*(dm_migs.user_seeks+dm_migs.user_scans) Avg_Estimated_Impact,
dm_migs.last_user_seek AS Last_User_Seek,
OBJECT_NAME(dm_mid.OBJECT_ID,dm_mid.database_id) AS [TableName],
'CREATE NONCLUSTERED INDEX [SK01_'
 + OBJECT_NAME(dm_mid.OBJECT_ID,dm_mid.database_id) +']'+ 

' ON ' + dm_mid.statement+ ' (' + ISNULL (dm_mid.equality_columns,'')
+ CASE WHEN dm_mid.equality_columns IS NOT NULL AND dm_mid.inequality_columns IS NOT NULL THEN ',' ELSE
'' END+ ISNULL (dm_mid.inequality_columns, '')
+ ')'+ ISNULL (' INCLUDE (' + dm_mid.included_columns + ')', '') AS Create_Statement,dm_migs.user_seeks,dm_migs.user_scans
FROM sys.dm_db_missing_index_groups dm_mig
INNER JOIN sys.dm_db_missing_index_group_stats dm_migs
ON dm_migs.group_handle = dm_mig.index_group_handle
INNER JOIN sys.dm_db_missing_index_details dm_mid
ON dm_mig.index_handle = dm_mid.index_handle
WHERE dm_mid.database_ID = DB_ID()
and dm_migs.last_user_seek >= getdate()-1
ORDER BY Avg_Estimated_Impact DESC

--	Valide o consumo da query
SET STATISTICS IO ON

select * 
from TestesIndices  
where cod = 543028

--	Table 'TestesIndices'. Scan count 1, logical reads 14293, physical reads 0, read-ahead reads 0, 
--	lob logical reads 0, lob physical reads 0, lob read-ahead reads 0.

--	Vamos seguir a sugestão do SQL e criar um índice na coluna que ele pediu. Botão direito em cima da dica, Show missed index details.
select * 
from TestesIndices  
where cod = 543028

--	Altere o comando para ficar no seu padrão
CREATE NONCLUSTERED INDEX SK01_TestesIndices
ON [dbo].[TestesIndices] ([Cod]) with(FILLFACTOR=95)

--	Execute a query novamente
select * 
from TestesIndices  
where cod = 543028

--	Consumo
--	Table 'TestesIndices'. Scan count 1, logical reads 2, physical reads 0, read-ahead reads 0, 
--	lob logical reads 0, lob physical reads 0, lob read-ahead reads 0.

--	Analisar se realmente o índice que o SQL sugeriu está sendo utilizado
select	getdate(), o.Name,i.name, s.user_seeks,s.user_scans,s.user_lookups, s.user_Updates, 
		isnull(s.last_user_seek,isnull(s.last_user_scan,s.last_User_Lookup)) Ultimo_acesso, fill_factor
from sys.dm_db_index_usage_stats s
	 join sys.indexes i on i.object_id = s.object_id and i.index_id = s.index_id
	 join sys.sysobjects o on i.object_id = o.id
where s.database_id = db_id() and o.name in ('TestesIndices') --and i.name = 'SK02_Telefone_Cliente'
order by s.user_seeks + s.user_scans + s.user_lookups desc


--	Voltar para os slides

--------------------------------------------------------------------------------------------------------------------------------
--	7)	Dicas para Tuning
--------------------------------------------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------------------------------------------
--	7.1)	Análise das queries demoradas
--------------------------------------------------------------------------------------------------------------------------------
--	Simulando uma query lenta que aparece no traces várias vezes

--	Executar 3 vezes
waitfor delay '00:00:03'
select *
from TestesIndices
where COd = 1235

--	Rodar o Job
EXEC msdb.dbo.sp_start_job 'DBA - Trace Banco de Dados'

--	Analisar o Traces
select *
from Traces..Traces
where starttime >= '20150501 12:30'
order by reads desc

--	Pegar as queries do Traces:

--	Queries que mais demoram
select *
from Traces..Traces
order by duration desc

--	Queries que mais se repetem
select *
from Traces..Traces
order by textdata desc

--	Queries que mais fazem READS
select *
from Traces..Traces
order by reads desc

--	Se preciso, queries que mais consomem CPU. Normalmente só os 3 primeiros já identificam as piores queries.
select *
from Traces..Traces
order by CPU desc

--	Em seguida você deve analisar essas queries para poder melhorar.

--	Sempre habilite o Ctrl + M e o SET STATISTICS IO ON
set statistics io on

--	Executar a query, analisar o executio plan e a aba Messages
select *
from TestesIndices
where COd = 1235

--	Caso o SQL não sugira um índice, você pode:
--		- Analisar o Execution plan da query e ver se consegue criar um índice melhor do que o índice que o SQL escolheu para essa query
--		- Analisar a query e ver se ela pode ser feita de outra forma (sub-queries, conversão implicita, funções na cláusula WHERE e etc).  
--		- Validar se a query tem filtros o suficiente. Se uma query da um join de 5 tabelas e coloca filtros pequenos que fazem ela 
--		  retorrar quase toda a tabela, nesse caso não resta muita coisa a se fazer a não ser mandar a query para avaliação do desenvolvedor.

--	Não vou entrar em mais detalhes, pois descer o nível no Tuning para análise de queries não é foco do treinamento (por questão de tempo). 
--	Podemos ficar 40 horas falando só de Tuning em um treinamento.
--	O Objetivo aqui é vocês conseguirem identificar essas queries e começar a trabalhar na análise de acordo com essas dicas que eu dei.



--------------------------------------------------------------------------------------------------------------------------------
--	7.2)	Análise de algumas DMVs para também ajudar na melhoria de performance
--------------------------------------------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------------------------------------------
--	7.2.1)	Verifica as databases mais utilizadas do seu banco de dados
--------------------------------------------------------------------------------------------------------------------------------
--	Essa query voce pode ordenar por leitura(num_of_reads) e/ou escrita (num_of_writes) para analisar os arquivos que mais 
--	possuem determinado tipo de operação
SELECT
	DB_NAME(mf.database_id) AS databaseName,
	name AS File_LogicalName,
	CASE
	WHEN type_desc = 'LOG' THEN 'Log File'
	WHEN type_desc = 'ROWS' THEN 'Data File'
	ELSE type_desc
	END AS File_type_desc
	,mf.physical_name
	,num_of_reads
	,num_of_bytes_read
	,io_stall_read_ms
	,num_of_writes
	,num_of_bytes_written
	,io_stall_write_ms
	,io_stall
	,size_on_disk_bytes
	,size_on_disk_bytes/ 1024 AS size_on_disk_KB
	,size_on_disk_bytes/ 1024 / 1024 AS size_on_disk_MB
	,size_on_disk_bytes/ 1024 / 1024 / 1024 AS size_on_disk_GB
FROM sys.dm_io_virtual_file_stats(NULL, NULL) AS divfs
JOIN sys.master_files AS mf ON mf.database_id = divfs.database_id
AND mf.FILE_ID = divfs.FILE_ID
ORDER BY num_of_Reads + num_of_writes DESC

--------------------------------------------------------------------------------------------------------------------------------
--	7.2.2)	TOP 50 queries executadas mais vezes
--------------------------------------------------------------------------------------------------------------------------------
if object_id('tempdb..#Temp_Trace') is not null drop table #Temp_Trace

SELECT TOP 50  execution_count, sql_handle,last_execution_time,last_worker_time,total_worker_time
into #Temp_Trace
FROM sys.dm_exec_query_stats A
where last_elapsed_time > 20
ORDER BY A.execution_count DESC

select distinct *
from #Temp_Trace A
cross apply sys.dm_exec_sql_text (sql_handle)
order by 1 DESC

--------------------------------------------------------------------------------------------------------------------------------
--	7.2.3)	TOP 50 queries com mais leituras (total_physical_reads + total_logical_reads + total_logical_writes)
--------------------------------------------------------------------------------------------------------------------------------
if object_id('tempdb..#Temp_Trace') is not null drop table #Temp_Trace

SELECT TOP 50  total_physical_reads + total_logical_reads + total_logical_writes IO,
 sql_handle,execution_count,last_execution_time,last_worker_time,total_worker_time
into #Temp_Trace
FROM sys.dm_exec_query_stats A
where last_elapsed_time > 20	
ORDER BY A.total_physical_reads + A.total_logical_reads + A.total_logical_writes DESC

select distinct *
from #Temp_Trace A
cross apply sys.dm_exec_sql_text (sql_handle)
order by 1 desc

--------------------------------------------------------------------------------------------------------------------------------
--	7.2.4)	TOP 50 queries com maior consumo de CPU
--------------------------------------------------------------------------------------------------------------------------------
if object_id('tempdb..#Temp_Trace') is not null drop table #Temp_Trace

SELECT TOP 50 total_worker_time ,  sql_handle,execution_count,last_execution_time,last_worker_time
into #Temp_Trace
FROM sys.dm_exec_query_stats A
--where last_elapsed_time > 20
	--and last_execution_time > dateadd(ss,-600,getdate()) --ultimos 5 min
order by A.total_worker_time desc

select distinct *
from #Temp_Trace A
cross apply sys.dm_exec_sql_text (sql_handle)
order by 1 DESC

-----------------------
-- Rotina para excluir dados antigos das tabelas que criamos até aqui
-----------------------

--Abrir e executar o script abaixo
--	"..\Tarefas do dia a dia de um DBA\Modulo 06 - Tuning\Demo Script expurgo dados antigos.sql"


--	Voltar para os slides


-----------------------
-- Query Store
-----------------------

--Abrir e executar o script abaixo
--	"..\Tarefas do dia a dia de um DBA\Modulo 06 - Tuning\Demo QueryStore.sql"