Create or Alter procedure dbo.ProcStatusAcordos as

------------------------------> Descrição da procedure

/*
    Padrão de escrita: PascalCase
    Nome: ProcStatusAcordos
    DataCriação: 13/08/2026
    Criado por: João Henrique Cavalheiro Grillo
    DataAtualização:
    Atualizado por:

    Descrição atualização: (Data, Atualizado por, Descrição, git)
*/

------------------------------> Definições de variaveis e controles de ambiente

Set nocount on;

Declare @NomeProcedure varchar(128) = 'ProcStatusAcordos',
        @Etapa varchar(100) = 'Inicio',
        @IdStatusAcordo int,
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

--- | Status acordos 

If Object_id('Tempdb..#StatusAcordos') Is not null Drop table #StatusAcordos;
Create table #StatusAcordos (
    IdStatusAcordo int,
    StatusAcordo varchar(64)
);

------------------------------> Carga das tabelas temporarias

Set @Etapa = 'Carga das tabelas temporarias';

Set @IdStatusAcordo = (Select Max(IdStatusAcordo) From misitau.dbo.StatusAcordos With(nolock));

Insert into #StatusAcordos (
                       IdStatusAcordo,
					   StatusAcordo
                       )
Select
    IdStatusAcordo,
	StatusAcordo
From misitau.cob.StatusAcordos
Where
    IdStatusAcordo > isnull(@IdStatusAcordo, 0);

Set @LinhasOrigem = @@RowCount;

------------------------------> Criacao de indices

Set @Etapa = 'Criacao de indices';

/* Cria index não clusterizado */
Create nonclustered index IxStatusAcordos on #StatusAcordos (IdStatusAcordo);

------------------------------> Persistencia final

Set @Etapa = 'Persistencia final';

--- | Tabela fisica

Insert into misitau.dbo.StatusAcordos (
                                   IdStatusAcordo,
                                   StatusAcordo
                                   )
Select
    IdStatusAcordo,
    StatusAcordo
From #StatusAcordos a With(nolock)
Where
    Not exists (Select 1
                From misitau.dbo.StatusAcordos b With(nolock)
                Where
                    a.IdStatusAcordo = b.IdStatusAcordo);

Set @LinhasInseridas = @@RowCount;
Set @LinhasTotaisDestino = @LinhasInseridas;
Set @DataHoraFim = Dateadd(hour,-3,Getdate());

/* Grava volumetria controles de log */
Exec misitau.[log].ProcControles
     @TipoLog = 'Volumetria',
     @IdExecucao = @IdExecucao,
     @NomeTabelaOrigem = 'cob.StatusAcordos',
     @NomeTabelaDestino = 'dbo.StatusAcordos',
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
Set @LinhaErro = Error_line();

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