Create or Alter dbo.ProcOrigemLigacoes as

------------------------------> Descrição da procedure

/*
    Padrão de escrita: PascalCase
    Nome: ProcOrigensLigacoes
    DataCriação: 24/07/2026
    Criado por: Leonardo Matheus Talarico
    DataAtualização:
    Atualizado por:

    Descrição atualização: (Data, Atualizado por, Descrição, git)
*/

------------------------------> Definições de variaveis e controles de ambiente

Set Nocount On;

Declare @NomeProcedure varchar(128) = 'ProcOrigensLigacoes',
        @Etapa varchar(100) = 'Inicio',
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

Begin Try

------------------------------> Criacao de tabelas temporarias

Set @Etapa = 'Criacao das tabelas temporarias';

--- | Usuarios

If Object_id('Tempdb..#OrigensLigacoes') Is not null Drop table #OrigensLigacoes;
Create table #OrigensLigacoes (
    IdOrigemLigacao char(1),
    OrigemLigacao varchar(32),
    CodigoReferencia varchar(8)
);

------------------------------> Carga das tabelas temporarias

Set @Etapa = 'Carga das tabelas temporarias';

--- | Insere novos usuarios e atualizados

Insert into #OrigensLigacoes (
                        IdOrigemLigacao,
                        OrigemLigacao,
                        CodigoReferencia
                        )
Select
    IdOrigemLigacao,
    OrigemLigacao,
    CodigoReferencia
From misitau.lig.OrigensLigacoes a
Where
    Not exists (Select 1
                From misitau.lig.OrigensLigacoes b
                Where
                    a.IdOrigemLigacao = b.IdOrigemLigacao);

Set @LinhasOrigem = @@RowCount;

------------------------------> Criacao de índices

Set @Etapa = 'Criacao de indices';

/* Cria index não clusterizado */
Create nonclustered index IxOrigensLigacoes on #OrigensLigacoes (IdOrigemLigacao);

------------------------------> Persistencia final

Set @Etapa = 'Persistencia final';

--- | Tabela fisica

Insert into misitau.dbo.OrigensLigacoes (
                                    IdOrigemLigacao,
                                    OrigemLigacao,
                                    CodigoReferencia
                                    )
Select distinct
    IdOrigemLigacao,
    OrigemLigacao,
    CodigoReferencia
From #OrigensLigacoes a With(nolock)
Where
    Not exists (Select 1
                From misitau.dbo.OrigensLigacoes b With(nolock)
                Where
                    a.IdOrigemLigacao = b.IdOrigemLigacao);

Set @LinhasInseridas = @@RowCount;
Set @LinhasTotaisDestino = @LinhasInseridas;
Set @DataHoraFim = Dateadd(hour,-3,Getdate());

/* Grava volumetria controles de log */
Exec misitau.[log].ProcControles
    @TipoLog = 'Volumetria',
    @IdExecucao = @IdExecucao,
    @NomeTabelaOrigem = 'lig.OrigensLigacoes',
    @NomeTabelaDestino = 'dbo.OrigensLigacoes',
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