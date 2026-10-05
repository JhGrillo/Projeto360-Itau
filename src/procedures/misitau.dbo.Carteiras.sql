Create or Alter Procedure dbo.ProcCarteiras as 
------------------------------> Descrição da procedure

/*
    Padrão de escrita: PascalCase
    Nome: ProcCarteiras
    DataCriação: 27/07/2026
    Criado por: João Henrique Cavalheiro Grillo
    DataAtualização: 02/10/2026
    Atualizado por: Leonardo Matheus Talarico

    Descrição atualização: (Data, Atualizado por, Descrição, git)

    02/10/2026 Leonardo Matheus Talarico: Foi adicionado dentro do codigo um trecho que verificará a média da volumetria das últimas atualizações e
    também a máxima volumetria dos ultimos 3 meses diariamente. Caso a quantidade de Linhas atualizadas e inseridas na tabela final for maior que
    as atualizações recentes e também maior que 75% do que a média histórica, é lido somente 10% da tabela de destino e é recalculado a distribuição
    dos dados ao atualizar as métricas do otimizador de consultas
*/

------------------------------> Definições de variaveis e controles de ambiente

Set Nocount On;

Declare @NomeProcedure varchar(128) = 'ProcCarteiras',
        @Etapa varchar(100) = 'Inicio',
        @IdCarteira int,
        @IdExecucao int,
        @MediaUltimasExecucoes int,
        @MediaVolumetria int,
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

If Object_id('Tempdb..#Carteiras') Is not null Drop table #Carteiras;
Create table #Carteiras (
    IdCarteira smallint,
    IdCliente smallint,
    CodigoReferencia smallint,
    Carteira varchar(64),
    RazaoSocial varchar(128)
);

------------------------------> Carga das tabelas temporarias

Set @Etapa = 'Carga das tabelas temporarias';

--- | Insere novos usuarios e atualizados

Set @IdCarteira = (Select Max(IdCarteira) From misitau.dbo.Carteiras With(nolock));

Insert into #Carteiras (
                        IdCarteira,
                        IdCliente,
                        CodigoReferencia,
                        Carteira,
                        RazaoSocial
                        )
Select
    IdCarteira,
    IdCliente,
    CodigoReferencia,
    Carteira,
    RazaoSocial
From misitau.glo.Carteiras a
Where
    IdCliente = 5
    and IdCarteira > @IdCarteira;

Set @LinhasOrigem = @@RowCount;

------------------------------> Criacao de índices

Set @Etapa = 'Criacao de indices';

/* Cria index não clusterizado */
Create nonclustered index IxCarteiras on #Carteiras (IdCarteira);

------------------------------> Persistencia final

Set @Etapa = 'Persistencia final';

--- | Tabela fisica

Insert into misitau.dbo.Carteiras (
                                IdCarteira,
                                IdCliente,
                                CodigoReferencia,
                                Carteira,
                                RazaoSocial
                                )
Select distinct
    IdCarteira,
    IdCliente,
    CodigoReferencia,
    Carteira,
    RazaoSocial
From #Carteiras a With(nolock)
Where
    Not exists (Select 1
                From misitau.dbo.Carteiras b With(nolock)
                Where
                    a.IdCarteira = b.IdCarteira);

Set @LinhasInseridas = @@RowCount;
Set @LinhasTotaisDestino = @LinhasInseridas;

Set @MediaUltimasExecucoes = (Select 
                                avg (LinhasTotaisDestino)
                              From (Select top 10
                                        LinhasTotaisDestino
                                    From misitau.log.ControleVolumes With(nolock)
                                    Where   
                                        NomeTabelaDestino = 'dbo.Carteiras'
                                    Order by
                                        IdControleVolume desc) a);

Set @MediaVolumetria = (Select
                            avg (LinhasTotaisDestino)
                        From (Select
                                Max(LinhasTotaisDestino) as LinhasTotaisDestino
                              From
                                misitau.log.ControleVolumes With(nolock)
                              Where
                                NomeTabelaDestino = 'dbo.Carteiras'
                              Group by
                                Convert(date, DataExecucao)) a);

If @LinhasTotaisDestino > @MediaUltimasExecucoes and @LinhasTotaisDestino >= @MediaVolumetria * 0.75
Begin
    Update Statistics misitau.dbo.Carteiras With Sample 10 Percent;
End;

Set @DataHoraFim = Dateadd(hour,-3,Getdate());

/* Grava volumetria controles de log */
Exec misitau.[log].ProcControles
    @TipoLog = 'Volumetria',
    @IdExecucao = @IdExecucao,
    @NomeTabelaOrigem = 'glo.Carteiras',
    @NomeTabelaDestino = 'dbo.Carteiras',
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