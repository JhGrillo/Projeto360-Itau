Create or Alter procedure dbo.ProcTiposEventos as

------------------------------> Descrição da procedure

/*
    Padrão de escrita: PascalCase
    Nome: ProcTiposEventos
    DataCriação: 24/07/2026
    Criado por: Leonardo Matheus talarico
    DataAtualização:
    Atualizado por:

    Descrição atualização: (Data, Atualizado por, Descrição, git)
*/

------------------------------> Definições de variaveis e controles de ambiente

Set nocount on;

Declare @NomeProcedure varchar(128) = 'ProcTiposEventos',
        @Etapa varchar(100) = 'Inicio',
        @IdTipoEvento int,
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

--- | Tipo ocorrências

If Object_id('Tempdb..#TiposEventos') Is not null Drop table #TiposEventos;
Create table #TiposEventos (
    IdTipoEvento smallint,
    IdTipoEventoReferencia smallint,
    IdSegmentacao char(1),
    CodigoEvento varchar(32),
    TipoEvento varchar(64),
    Agendamento char(1),
    DataComplementar char(1),
    ExigeComplemento char(1),
    Sistema char(1),
    IdClassificacao tinyint
);

------------------------------> Carga das tabelas temporarias

Set @Etapa = 'Carga das tabelas temporarias';

Set @IdTipoEvento = (Select Max(IdTipoEvento) From misitau.dbo.TiposEventos With(nolock));

Insert into #TiposEventos (
                            IdTipoEvento,
                            IdTipoEventoReferencia,
                            IdSegmentacao,
                            CodigoEvento,
                            TipoEvento,
                            Agendamento,
                            DataComplementar,
                            ExigeComplemento,
                            Sistema,
                            IdClassificacao
                            )
Select
    IdTipoEvento,
    IdTipoEventoReferencia,
    IdSegmentacao,
    CodigoEvento,
    TipoEvento,
    Agendamento,
    DataComplementar,
    ExigeComplemento,
    Sistema,
    IdClassificacao
From misitau.glo.TiposEventos
Where
    IdTipoEvento > isnull(@IdTipoEvento, 0);

Set @LinhasOrigem = @@RowCount;

------------------------------> Criacao de indices

Set @Etapa = 'Criacao de indices';

/* Cria index não clusterizado */
Create nonclustered index IxTiposEventos on #TiposEventos (IdTipoEvento);

------------------------------> Persistencia final

Set @Etapa = 'Persistencia final';

--- | Tabela fisica

Insert into misitau.dbo.TiposEventos (
                                IdTipoEvento,
                                IdTipoEventoReferencia,
                                IdSegmentacao,
                                CodigoEvento,
                                TipoEvento,
                                Agendamento,
                                DataComplementar,
                                ExigeComplemento,
                                Sistema,
                                IdClassificacao
                                )
Select
    IdTipoEvento,
    IdTipoEventoReferencia,
    IdSegmentacao,
    CodigoEvento,
    TipoEvento,
    Agendamento,
    DataComplementar,
    ExigeComplemento,
    Sistema,
    IdClassificacao
From #TiposEventos a With(nolock)
Where
    Not exists (Select 1
                From misitau.dbo.TiposEventos b With(nolock)
                Where
                    a.IdTipoEvento = b.IdTipoEvento);

Set @LinhasInseridas = @@RowCount;
Set @LinhasTotaisDestino = @LinhasInseridas;
Set @DataHoraFim = Dateadd(hour,-3,Getdate());

/* Grava volumetria controles de log */
Exec misitau.[log].ProcControles
    @TipoLog = 'Volumetria',
    @IdExecucao = @IdExecucao,
    @NomeTabelaOrigem = 'oco.TiposEventos',
    @NomeTabelaDestino = 'dbo.TiposEventos',
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