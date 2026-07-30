Create or Alter procedure dbo.ProcEscob as

------------------------------> Descrição da procedure

/*
    Padrão de escrita: PascalCase
    Nome: ProcEscob
    DataCriação: 30/07/2026
    Criado por: João Henrique Cavalheiro Grillo
    DataAtualização:
    Atualizado por:

    Descrição atualização: (Data, Atualizado por, Descrição, git)
*/

------------------------------> Definições de variaveis e controles de ambiente

Set nocount on;

Declare @NomeProcedure varchar(128) = 'ProcEscob',
    @Etapa varchar(100) = 'Inicio',
    @IdEscob int,
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

--- | Escob

If Object_id('Tempdb..#Escob') Is not null Drop table #Escob;
Create table #Escob (
    IdEscob int,
    IdDevedor int,
    IdTitulo int,
    Cluster varchar(10),
    DataAtualizacao datetime
);

------------------------------> Carga das tabelas temporarias

Set @Etapa = 'Carga das tabelas temporarias';

--- | Insere devedores novos ou atualizados

Set @IdEscob = (Select Max(IdEscob) From misitau.dbo.Escob With(nolock));
Set @UltimaAtualizacao = (Select 
                            Case
                                when Datepart(hour,Max(DataHoraInicio)) >= 22 then Max(Dateadd(day,+1,Convert(date,DataHoraInicio)))
                                else Max(Convert(date,DataHoraInicio))
                            end
                          From misitau.[log].ControleExecucoes
                          Where
                            NomeProcedure = 'ProcEscob'
                            and StatusExecucao = 'Concluida');

Insert into #Escob (
                    IdEscob,
                    IdDevedor,
                    IdTitulo,
                    Cluster,
                    DataAtualizacao
                    )
Select
    IdEscob,
    IdDevedor,
    IdTitulo,
    Cluster,
    DataAtualizacao
From misitau.cli.Escob a
Where
    (IdEscob > Isnull(@IdEscob,0)
    or DataAtualizacao >= @UltimaAtualizacao)
    and Not exists (Select 1
                    From misitau.dbo.Escob b With(nolock)
                    Where
                        a.IdEscob = b.IdEscob
                        and Isnull(a.DataAtualizacao,'1900-01-01') = Isnull(b.DataAtualizacao,'1900-01-01'));

Set @LinhasOrigem = @@RowCount;

------------------------------> Criacao de indices

Set @Etapa = 'Criacao de indices';

/* Cria index não clusterizado */
Create nonclustered index IxEscob on #Escob (IdEscob);

------------------------------> Persistencia final

Set @Etapa = 'Persistencia final';

--- | Tabela fisica

Insert into misitau.dbo.Escob (
                            IdEscob,
                            IdDevedor,
                            IdTitulo,
                            Cluster,
                            DataAtualizacao
                            )
Select distinct
    IdEscob,
    IdDevedor,
    IdTitulo,
    Cluster,
    DataAtualizacao
From #Escob a With(nolock)
Where
    Not exists (Select 1
                From misitau.dbo.Escob b With(nolock)
                Where
                 a.IdEscob = b.IdEscob);

Set @LinhasInseridas = @@RowCount;

------------------------------> Atualizacao de dados

Set @Etapa = 'Atualizacao de dados';

--- | Atualiza campos da tabela fisica

Update a
Set a.Cluster = b.Cluster,
    a.DataAtualizacao = b.DataAtualizacao
From misitau.dbo.Escob a With(nolock)
Inner join #Escob b With(nolock) on a.IdEscob = b.IdEscob
Where
    Isnull(a.DataAtualizacao,'1900-01-01') <> Isnull(b.DataAtualizacao,'1900-01-01');

Set @LinhasAtualizadas = @@RowCount;
Set @LinhasTotaisDestino = @LinhasInseridas + @LinhasAtualizadas;
Set @DataHoraFim = Dateadd(hour,-3,Getdate());

/* Grava volumetria controles de log */
Exec misitau.[log].ProcControles
    @TipoLog = 'Volumetria',
    @IdExecucao = @IdExecucao,
    @NomeTabelaOrigem = 'cli.Escob',
    @NomeTabelaDestino = 'dbo.Escob',
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