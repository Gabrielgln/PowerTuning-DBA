use master
-- DROP DATABASE IF EXISTS QueryStore_TreinamentoDBA --comando apenas do sql 2016
CREATE DATABASE QueryStore_TreinamentoDBA

USE [master]
GO
ALTER DATABASE [QueryStore_TreinamentoDBA] SET QUERY_STORE = ON
GO
ALTER DATABASE [QueryStore_TreinamentoDBA] SET QUERY_STORE (OPERATION_MODE = READ_WRITE, MAX_STORAGE_SIZE_MB = 1000, QUERY_CAPTURE_MODE = AUTO)
GO

use QueryStore_TreinamentoDBA
GO

if object_id('TestesIndices') is not null 
	drop table TestesIndices

create table TestesIndices(
	Cod int,
	Data datetime default(getdate()),
	Descricao varchar(1000)
)

--	Populando a tabela com 100 mil registros (1 minuto)
insert into TestesIndices(Cod,Descricao)
select cast(1000000000*rand()/1000 as int),replicate('0',1000)
GO 100000

-- simular duas execuções diferentes de queries
select *
from TestesIndices
where Cod = 18
GO 100

select *
from TestesIndices
where Data = '2016-04-25 20:38:00.820'
GO 100


--Abrir o gráfico Top Resource Consuming Queries 

--Removendo a query de insert
EXEC sp_query_store_remove_query 1

--Criando um índice
create nonclustered index SK01_TestesIndices on TestesIndices(Cod) with(FILLFACTOR=95)

select *
from TestesIndices
where Cod = 18
GO 100

--Pegar um Cod que existe 
select top 1 *
from TestesIndices

--Fazer um replace ALL nesse código e inserir 50 mil linhas com ele.
insert into TestesIndices
select top 50000 868449,getdate(),''
from TestesIndices

-- Pegar um outro código para fazer testes e comparar
--habilitar o ctrl+M

set statistics io on

select top 2 *
from TestesIndices

select  *
from TestesIndices
where Cod = 868449
--Salvar o custo da query
Table 'TestesIndices'. Scan count 1, logical reads 14293, physical reads 0, read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob read-ahead reads 0.


select  *
from TestesIndices
where Cod = 948857
--Salvar o custo da query
Table 'TestesIndices'. Scan count 1, logical reads 4, physical reads 0, read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob read-ahead reads 0.


CREATE procedure stpTeste_QueryStore @Cod int
AS
	select Cod,Data
	into #Temp
	from TestesIndices
	where Cod = @Cod 


exec stpTeste_QueryStore 948857

exec stpTeste_QueryStore 868449


sp_recompile stpTeste_QueryStore

exec stpTeste_QueryStore 868449

exec stpTeste_QueryStore 948857

-- Olhar no grafico e forçar um plano

-- Forçar o plano com seek
exec stpTeste_QueryStore 868449

sp_recompile stpTeste_QueryStore

exec stpTeste_QueryStore 948857


-- Se metade das execuções de produção usar um parametro para scan e metade para seek, a solução é com OPTION(RECOMPILE)
ALTER procedure stpTeste_QueryStore @Cod int
AS
	select Cod,Data
	into #Temp
	from TestesIndices
	where Cod = @Cod 
	OPTION(RECOMPILE)



--Testes com a procedure recompilando
exec stpTeste_QueryStore 948857

exec stpTeste_QueryStore 868449

--Problema!!! Vai consumir CPU para compilar a toda execução

ALTER DATABASE QueryStore_TreinamentoDBA SET QUERY_STORE CLEAR;


--tirar o ctrl+m
exec stpTeste_QueryStore 948857 --seek + lookup
GO 100

exec stpTeste_QueryStore 868449 --scan
GO 100


