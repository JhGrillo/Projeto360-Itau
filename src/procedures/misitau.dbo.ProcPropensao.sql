Create or Alter procedure dbo.ProcPropensao as

------------------------------> Descrição da procedure

/*
    Padrão de escrita: PascalCase
    Nome: ProcEscob
    DataCriação: 31/07/2026
    Criado por: João Henrique Cavalheiro Grillo
    DataAtualização:
    Atualizado por:

    Descrição atualização: (Data, Atualizado por, Descrição, git)
*/

------------------------------> Definições de variaveis e controles de ambiente

Set nocount on;

Declare @NomeProcedure varchar(128) = 'ProPropensao',
    @Etapa varchar(100) = 'Inicio',
    @IdPropensao int,
    @UltimaAtualizacao datetime,
    @IdExecucao int,
    @LinhasOrigem int,
    @LinhasInseridas int,
    @LinhasAtualizadas int,
    @LinhasTotaisDestino int,
    @DataHoraInicio datetime = Dateadd(hour,-3,Getdate()),
    @DataHoraFim datetime,
    @MensagemErro varchar(max),
    @NumeroErro int,
    @LinhaErro int;

/* Inicia o controle de logs */
Exec misitau.[log].ProcControles
    @TipoLog = 'Execucao',
    @NomeProcedure = @NomeProcedure,
    @DataHoraInicio = @DataHoraInicio,
    @StatusExecucao = 'Executando',
    @IdExecucao = @IdExecucao OUTPUT

Begin try
------------------------------> Criacao das tabelas temporarias

Set @Etapa = 'Criacao das tabelas temporarias';

--- | Propensao

If Object_id('Tempdb..#Propensao') Is not null Drop table #Propensao;
Create table #Propensao (
    IdPropensao int,
    IdTitulo int,
    Cluster varchar(12),
    DataAtualizacao datetime
);

------------------------------> Carga das tabelas temporarias

Set @Etapa = 'Carga das tabelas temporarias';

--- | Insere devedores novos ou atualizados

Set @IdPropensao = (Select Max(IdPropensao) From misitau.dbo.Propensao With(nolock));
Set @UltimaAtualizacao = (Select 
                            Case
                                when Datepart(hour,Max(DataHoraInicio)) >= 22 then Max(Dateadd(day,+1,Convert(date,DataHoraInicio)))
                                else Max(Convert(date,DataHoraInicio))
                            end
                          From misitau.[log].ControleExecucoes
                          Where
                            NomeProcedure = 'ProcPropensao'
                            and StatusExecucao = 'Concluida');

Insert into #Propensao (
                    IdPropensao,
                    IdTitulo,
                    Cluster,
                    DataAtualizacao
                    )
Select
    IdPropensao,
    IdTitulo,
    Cluster,
    DataAtualizacao
From misitau.cli.Propensao a
Where
    (IdPropensao > Isnull(@IdPropensao,0)
    or DataAtualizacao >= @UltimaAtualizacao)
    and Not exists (Select 1
                    From misitau.dbo.Propensao b With(nolock)
                    Where
                        a.IdPropensao = b.IdPropensao
                        and Isnull(a.DataAtualizacao,'1900-01-01') = Isnull(b.DataAtualizacao,'1900-01-01'));

Set @LinhasOrigem = @@RowCount;

------------------------------> Criacao de indices

Set @Etapa = 'Criacao de indices';

/* Cria index não clusterizado */
Create nonclustered index IxEscob on #Propensao (IdPropensao);

------------------------------> Persistencia final

Set @Etapa = 'Persistencia final';

--- | Tabela fisica

Insert into misitau.dbo.Propensao (
                                IdPropensao,
                                IdTitulo,
                                Cluster,
                                DataAtualizacao
                                )
Select distinct
    IdPropensao,
    IdTitulo,
    Cluster,
    DataAtualizacao
From #Propensao a With(nolock)
Where
    Not exists (Select 1
                From misitau.dbo.Propensao b With(nolock)
                Where
                 a.IdPropensao = b.IdPropensao);

Set @LinhasInseridas = @@RowCount;

------------------------------> Atualizacao de dados

Set @Etapa = 'Atualizacao de dados';

--- | Atualiza campos da tabela fisica

Update a
Set a.Cluster = b.Cluster,
    a.DataAtualizacao = b.DataAtualizacao
From misitau.dbo.Propensao a With(nolock)
Inner join #Propensao b With(nolock) on a.IdPropensao = b.IdPropensao
Where
    Isnull(a.DataAtualizacao,'1900-01-01') <> Isnull(b.DataAtualizacao,'1900-01-01');

Set @LinhasAtualizadas = @@RowCount;
Set @LinhasTotaisDestino = @LinhasInseridas + @LinhasAtualizadas;
Set @DataHoraFim = Dateadd(hour,-3,Getdate());

/* Grava volumetria controles de log */
Exec misitau.[log].ProcControles
    @TipoLog = 'Volumetria',
    @IdExecucao = @IdExecucao,
    @NomeTabelaOrigem = 'cli.Propensao',
    @NomeTabelaDestino = 'dbo.Propensao',
    @LinhasOrigem = @LinhasOrigem,
    @LinhasInseridas = @LinhasInseridas,
    @LinhasAtualizadas = @LinhasAtualizadas,
    @LinhasTotaisDestino = @LinhasTotaisDestino;

/* Finaliza execução controles de log concluido */
Exec misitau.[log].ProcControles
    @TipoLog = 'Atualizacao',
    @IdExecucao = @IdExecucao,
    @DataHoraFim = @DataHoraFim,
    @StatusExecucao = 'Concluida';

End Try
Begin Catch

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