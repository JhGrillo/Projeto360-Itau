Create or Alter procedure dbo.ProcTiposOcorrencias as

------------------------------> Descrição da procedure

/*
    Padrão de escrita: PascalCase
    Nome: ProcTiposOcorrencias
    DataCriação: 24/07/2026
    Criado por: João Henrique Cavalheiro Grillo
    DataAtualização:
    Atualizado por:

    Descrição atualização: (Data, Atualizado por, Descrição, git)
*/

------------------------------> Definições de variaveis e controles de ambiente

Set nocount on;

Declare @NomeProcedure varchar(128) = 'ProcTiposOcorrencias',
    @Etapa varchar(100) = 'Inicio',
    @IdTipoOcorrencia int,
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
    @IdExecucao = @IdExecucao OUTPUT;

Begin try

------------------------------> Criacao das tabelas temporarias

Set @Etapa = 'Criacao das tabelas temporarias';

--- | Tipo ocorrências

If Object_id('Tempdb..#TiposOcorrencias') Is not null Drop table #TiposOcorrencias;
Create table #TiposOcorrencias (
    IdTipoOcorrencia smallint,
    IdTipoOcorrenciaReferencia smallint,
    IdSegmentacao char(1),
    CodigoOcorrencia varchar(32),
    TipoOcorrencia varchar(64),
    Agendamento char(1),
    DataComplementar char(1),
    ExigeComplemento char(1),
    Sistema char(1),
    IdClassificacao tinyint
);

------------------------------> Carga das tabelas temporarias

Set @Etapa = 'Carga das tabelas temporarias';

Set @IdTipoOcorrencia = (Select Max(IdTipoOcorrencia) From misitau.dbo.TiposOcorrencias With(nolock));

Insert into #TiposOcorrencias (
                            IdTipoOcorrencia,
                            IdTipoOcorrenciaReferencia,
                            IdSegmentacao,
                            CodigoOcorrencia,
                            TipoOcorrencia,
                            Agendamento,
                            DataComplementar,
                            ExigeComplemento,
                            Sistema,
                            IdClassificacao
                            )
Select
    IdTipoOcorrencia,
    IdTipoOcorrenciaReferencia,
    IdSegmentacao,
    CodigoOcorrencia,
    TipoOcorrencia,
    Agendamento,
    DataComplementar,
    ExigeComplemento,
    Sistema,
    IdClassificacao
From misitau.glo.TiposOcorrencias
Where
    IdTipoOcorrencia > isnull(@IdTipoOcorrencia, 0);

Set @LinhasOrigem = @@RowCount;

------------------------------> Criacao de indices

Set @Etapa = 'Criacao de indices';

/* Cria index não clusterizado */
Create nonclustered index IxTiposOcorrencias on #TiposOcorrencias (IdTipoOcorrencia);

------------------------------> Persistencia final

Set @Etapa = 'Persistencia final';

--- | Tabela fisica

Insert into misitau.dbo.TiposOcorrencias (
                                    IdTipoOcorrencia,
                                    IdTipoOcorrenciaReferencia,
                                    IdSegmentacao,
                                    CodigoOcorrencia,
                                    TipoOcorrencia,
                                    Agendamento,
                                    DataComplementar,
                                    ExigeComplemento,
                                    Sistema,
                                    IdClassificacao
                                    )
Select
    IdTipoOcorrencia,
    IdTipoOcorrenciaReferencia,
    IdSegmentacao,
    CodigoOcorrencia,
    TipoOcorrencia,
    Agendamento,
    DataComplementar,
    ExigeComplemento,
    Sistema,
    IdClassificacao
From #TiposOcorrencias a With(nolock)
Where
    Not exists (Select 1
                From misitau.dbo.TiposOcorrencias b With(nolock)
                Where
                    a.IdTipoOcorrencia = b.IdTipoOcorrencia);

Set @LinhasInseridas = @@RowCount;
Set @LinhasTotaisDestino = @LinhasInseridas;
Set @DataHoraFim = Dateadd(hour,-3,Getdate());

/* Grava volumetria controles de log */
Exec misitau.[log].ProcControles
    @TipoLog = 'Volumetria',
    @IdExecucao = @IdExecucao,
    @NomeTabelaOrigem = 'oco.TiposOcorrencias',
    @NomeTabelaDestino = 'dbo.TiposOcorrencias',
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