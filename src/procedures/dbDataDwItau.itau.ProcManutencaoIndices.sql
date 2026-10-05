Create or Alter Procedure [itau].[ProcManutencaoIndices] as

------------------------------> Descrição da procedure

/*
	Padrão de escrita: PascalCase
	Nome: ProcManutencaoIndices
	DataCriação: 22/07/2026
	Criado por: João Henrique Cavalheiro Grillo
	DataAtualização: 05/10/2026
	Atualizado por: Leonardo Matheus Talarico

	Descrição atualização: (Data, Atualizado por, Descrição, git)

    06/08/2026 João Henrique Cavalheiro Grillo: O processo não estava marcando concluído no log
    quando não havia nenhuma tabela para fazer manutenção, pois o Exec estava dentro do While contador de tabelas.

	05/10/2026 Leonardo Matheus Talarico:: Foi adicionado um Update Statistics Fullscan para as fragmentações maiores que 5.0 e menores que 30.0

*/

------------------------------> Definições de variaveis e controles de ambiente

Declare @NomeProcedure varchar(128) = 'ProcManutencaoIndices',
		@Etapa varchar(100) = 'Inicio',
		@IdExecucao int, 
		@DataHoraInicio datetime = Getdate(),
		@DataHoraFim datetime,
		@MensagemErro varchar(max),
		@NumeroErro int,
		@LinhaErro int,
		@Contador int,
		@Id int = 1,
		@SchemaTabela varchar(64),
		@NomeTabela varchar(64),
		@NomeIndex varchar(128),
		@Fragmentacao decimal(5,2),
		@SQL nvarchar(max);

/* Inicia o controle de logs */
Exec dbDataDwItau.[log].ProcControles
	@TipoLog = 'Execucao',
	@NomeProcedure = @NomeProcedure,
	@DataHoraInicio = @DataHoraInicio,
	@StatusExecucao = 'Executando',
	@IdExecucao = @IdExecucao OUTPUT;

Begin Try

---------------------------> Criacao de tabelas temporarias

Set @Etapa = 'Criacao das tabelas temporarias';

--- | Tabelas
If Object_id('Tempdb..#Tabelas') Is not null Drop table #Tabelas;
Create table #Tabelas (
    IdTabela int identity(1,1),
    SchemaTabela varchar(128),
    NomeTabela varchar(128),
    NomeIndex varchar(128),
    Fragmentacao decimal(5,2)
);

------------------------------> Carga das tabelas temporarias

Set @Etapa = 'Carga das tabelas temporarias';

--- | Insere as informações de tabelas

Insert into #Tabelas
Select
	b.Name as SchemaTabela,
	a.Name as NomeTabela,
	c.Name as NomeIndex,
	d.avg_fragmentation_in_percent as Fragmentacao
From sys.tables a With(nolock)
Inner Join sys.schemas b With(nolock) On a.schema_id = b.schema_id
Inner Join sys.indexes c With(nolock) On a.object_id = c.object_id
Cross Apply sys.dm_db_index_physical_stats(db_id(), a.object_id, c.index_id, null, 'Limited') d
Where
	a.is_ms_shipped = 0
	and c.index_id > 0
	and d.avg_fragmentation_in_percent >= 5.0
	and d.page_count > 1000; -- Ignora indices pequenos (< 8MB)

---------------------------> Manutencao de indices

Set @Etapa = 'Manutencao de indices';

Set @Contador = (Select Count(IdTabela) From #Tabelas);

While @Id <= @Contador
Begin

	Select
		@SchemaTabela = SchemaTabela,
		@NomeTabela = NomeTabela,
		@NomeIndex = NomeIndex,
		@Fragmentacao = Fragmentacao
	From #Tabelas
	Where
		IdTabela = @Id;

	If @Fragmentacao >= 30.0
	Begin
		Set @SQL = N'Alter Index ' + Quotename(@NomeIndex) + N' On ' + Quotename(@SchemaTabela) + N'.' + Quotename(@NomeTabela) + N' Rebuild With(Online=Off);';
		Exec sp_executesql @SQL;
	End
	Else If @Fragmentacao >= 5.0
	Begin
		Set @SQL = N'Alter Index ' + Quotename(@NomeIndex) + N' ON ' + Quotename(@SchemaTabela) + N'.' + Quotename(@NomeTabela) + N' Reorganize;';
		Exec sp_executesql @SQL;

		Set @SQL = N'Update Statistics ' + Quotename(@SchemaTabela) + N'.' + Quotename(@NomeTabela) + N' (' + Quotename(@NomeIndex) + N') With Fullscan;';
		Exec sp_executesql @SQL;
	End;

	Set @Id += 1;

End;

Set @DataHoraFim = Dateadd(hour,-3, Getdate());

/* Finaliza execução controles de log concluido */
Exec dbDataDwItau.[log].ProcControles
	@TipoLog = 'Atualizacao',
	@IdExecucao = @IdExecucao,
	@DataHoraFim = @DataHoraFim,
	@StatusExecucao = 'Concluida';

End try
Begin catch

Set @MensagemErro = ERROR_MESSAGE();
Set @NumeroErro = Error_number();
Set @LinhaErro = Error_line()

/* Finalizacao execução de log erro */
Set @DataHoraFim = Dateadd(hour,-3,Getdate());
Exec dbDataDwItau.[log].ProcControles
	@TipoLog = 'Atualizacao',
	@IdExecucao = @IdExecucao,
	@DataHoraFim = @DataHoraFim,
	@StatusExecucao = 'Erro';

/* Execução log erro */
Exec dbDataDwItau.[log].ProcControles
	@TipoLog = 'Erro',
	@IdExecucao = @IdExecucao,
	@NomeProcedure = @NomeProcedure,
	@MensagemErro = @MensagemErro,
	@NumeroErro = @NumeroErro,
	@LinhaErro = @LinhaErro,
	@EtapaErro = @Etapa;

End Catch;
