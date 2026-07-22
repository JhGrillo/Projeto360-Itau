Create or Alter procedure dbo.ProcManutencaoIndices as

------------------------------> Descrição da procedure

/*
	Padrão de escrita: PascalCase
	Nome: ProcManutencaoIndices
	DataCriação: 22/07/2026
	Criado por: João Henrique Cavalheiro Grillo
	DataAtualização:
	Atualizado por:

	Descrição atualização: (Data, Atualizado por, Descrição, git)
*/

------------------------------> Definições de variaveis e controles de ambiente

Set Nocount On;

Declare @NomeProcedure varchar(128) = 'ProcManutencaoIndices',
        @Etapa varchar(100) = 'Inicio',
        @IdExecucao int,
        @DataHoraInicio datetime = Dateadd(hour,-3,Getdate()),
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
Exec misitau.[log].ProcControles
    @TipoLog = 'Execucao',
    @NomeProcedure = @NomeProcedure,
    @DataHoraInicio = @DataHoraInicio,
    @StatusExecucao = 'Executando',
    @IdExecucao = @IdExecucao OUTPUT;

Begin Try

------------------------------> Criacao de tabelas temporarias

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
    and d.page_count > 1000; -- Ignora índices pequenos (< 8MB)

------------------------------> Manutencao de indices

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
    End
    Else If @Fragmentacao >= 5.0
    Begin
        Set @SQL = N'Alter Index ' + Quotename(@NomeIndex) + N' On ' + Quotename(@SchemaTabela) + N'.' + Quotename(@NomeTabela) + N' Reorganize;';
    End;

    Exec sp_executesql @SQL;

    Set @Id += 1;

End;

Set @DataHoraFim = Dateadd(hour,-3,Getdate());

/* Finaliza execução controles de log concluido */
Exec misitau.[log].ProcControles
    @TipoLog = 'Atualizacao',
    @IdExecucao = @IdExecucao,
    @DataHoraFim = @DataHoraFim,
    @StatusExecucao = 'Concluida';

End try
Begin catch

Set @MensagemErro = Error_message();
Set @NumeroErro = Error_number();
Set @LinhaErro = Error_line()


/* Finalizacao execução de log erro */
Set @DataHoraFim = Dateadd(hour,-3,Getdate());
Exec misitau.[log].ProcControles
    @TipoLog = 'Atualizacao',
    @IdExecucao = @IdExecucao,
    @DataHoraFim = @DataHoraFim,
    @StatusExecucao = 'Erro';

/* Execução log erro */
Exec misitau.[log].ProcControles
    @TipoLog = 'Erro',
    @IdExecucao = @IdExecucao,
    @NomeProcedure = @NomeProcedure,
    @MensagemErro = @MensagemErro,
    @NumeroErro = @NumeroErro,
    @LinhaErro = @LinhaErro,
    @EtapaErro = @Etapa;

End Catch;