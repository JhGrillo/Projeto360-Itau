Create or Alter procedure [dbo].[ProcOcorrencias] as

------------------------------> Descrição da procedure

/*
    Padrão de escrita: PascalCase
    Nome: ProcOcorrencias
    DataCriação: 24/07/2026
    Criado por: João Henrique Cavalheiro Grillo
    DataAtualização:
    Atualizado por:

    Descrição atualização: (Data, Atualizado por, Descrição, git)
*/

------------------------------> Definições de variaveis e controles de ambiente

Set nocount on;

Declare @NomeProcedure varchar(128) = 'ProcOcorrencias',
    @Etapa varchar(100) = 'Inicio',
    @IdOcorrencia int,
    @UltimaAtualizacao datetime,
    @SQLOcorrencias nvarchar(max),
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

--- | Ocorrências

If Object_id('Tempdb..#Ocorrencias') Is not null Drop table #Ocorrencias;
Create table #Ocorrencias (
    IdOcorrencia int,
    IdDevedor int,
    IdTitulo int,
    IdParcela int,
    IdTipoOcorrencia smallint,
    IdOrigem tinyint,
    IdLigacao int,
    DataOcorrencia datetime,
    DataComplementar datetime,
    Complemento varchar(max),
    DataInclusao datetime,
    IdUsuarioInclusao int,
    DataAtualizacao datetime,
    IdUsuarioAtualizacao int,
    IdAcordo int
);

------------------------------> Carga das tabelas temporarias

Set @Etapa = 'Carga das tabelas temporarias';

--- | Insere novas ocorrências na tabela

Set @IdOcorrencia = (Select Max(IdOcorrencia) as IdOcorrencia From misitau.dbo.Ocorrencias With(nolock));

Set @UltimaAtualizacao = (Select 
                            Case
                                when Datepart(hour,Max(DataHoraInicio)) >= 22 then Max(Dateadd(day,+1,Convert(date,DataHoraInicio)))
                                else Max(Convert(date,DataHoraInicio))
                            end
                         From misitau.[log].ControleExecucoes
                         Where
                            NomeProcedure = 'ProcOcorrencias'
                            and StatusExecucao = 'Concluida');

Set @SQLOcorrencias = N'
Insert into #Ocorrencias (
                        IdOcorrencia,
                        IdDevedor,
                        IdTitulo,
                        IdParcela,
                        IdTipoOcorrencia,
                        IdOrigem,
                        IdLigacao,
                        DataOcorrencia,
                        DataComplementar,
                        Complemento,
                        DataInclusao,
                        IdUsuarioInclusao,
                        DataAtualizacao,
                        IdUsuarioAtualizacao,
                        IdAcordo
                        )
Select
    IdOcorrencia,
    IdDevedor,
    IdTitulo,
    IdParcela,
    IdTipoOcorrencia,
    IdOrigem,
    IdLigacao,
    DataOcorrencia,
    DataComplementar,
    Complemento,
    DataInclusao,
    IdUsuarioInclusao,
    DataAtualizacao,
    IdUsuarioAtualizacao,
    IdAcordo
From misitau.oco.Ocorrencias a
Where
    ' + Case 
            when @IdOcorrencia is null then 'DataOcorrencia >= ''' + Convert(nvarchar(120),@UltimaAtualizacao) + '''' 
            else 'IdOcorrencia > ' + Convert(nvarchar,@IdOcorrencia) 
        end;

Exec sp_executesql @SQLOcorrencias;

Set @LinhasOrigem = @@RowCount;

------------------------------> Criacao de indices

Set @Etapa = 'Criacao de indices';

/* Cria index não clusterizado */
Create nonclustered index IxOcorrencia on #Ocorrencias (IdOcorrencia);

------------------------------> Persistencia final

Set @Etapa = 'Persistencia final';

--- | Tabela fisica

Insert into misitau.dbo.Ocorrencias (
                            IdOcorrencia,
                            IdDevedor,
                            IdTitulo,
                            IdParcela,
                            IdTipoOcorrencia,
                            IdOrigem,
                            IdLigacao,
                            DataOcorrencia,
                            DataComplementar,
                            Complemento,
                            DataInclusao,
                            IdUsuarioInclusao,
                            DataAtualizacao,
                            IdUsuarioAtualizacao,
                            IdAcordo
                            )
Select
    IdOcorrencia,
    IdDevedor,
    IdTitulo,
    IdParcela,
    IdTipoOcorrencia,
    IdOrigem,
    IdLigacao,
    DataOcorrencia,
    DataComplementar,
    Complemento,
    DataInclusao,
    IdUsuarioInclusao,
    DataAtualizacao,
    IdUsuarioAtualizacao,
    IdAcordo
From #Ocorrencias a With(nolock)
Where
    Not exists (Select 1
                From misitau.dbo.Ocorrencias b With(nolock)
                Where
                    a.IdOcorrencia = b.IdOcorrencia);

Set @LinhasInseridas = @@RowCount;
Set @LinhasTotaisDestino = @LinhasInseridas;
Set @DataHoraFim = Dateadd(hour,-3,Getdate());

/* Grava volumetria controles de log */
Exec misitau.[log].ProcControles
    @TipoLog = 'Volumetria',
    @IdExecucao = @IdExecucao,
    @NomeTabelaOrigem = 'oco.Ocorrencias',
    @NomeTabelaDestino = 'dbo.Ocorrencias',
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

End try
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