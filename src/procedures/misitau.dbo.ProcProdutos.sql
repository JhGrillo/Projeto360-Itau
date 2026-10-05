Create or Alter Procedure dbo.ProcProdutos as 

------------------------------> Descrição da procedure

/*
    Padrão de escrita: PascalCase
    Nome: ProcProdutos
    DataCriação: 24/07/2026
    Criado por: Leonardo Matheus talarico
    DataAtualização: 02/10/2026
    Atualizado por: Leonardo Matheus Talarico

    Descrição atualização: (Data, Atualizado por, Descrição, git)

    02/10/2026 Leonardo Matheus Talarico: Foi adicionado dentro do codigo um trecho que verificará a média da volumetria das últimas atualizações e
    também a máxima volumetria dos ultimos 3 meses diariamente. Caso a quantidade de Linhas atualizadas e inseridas na tabela final for maior que
    as atualizações recentes e também maior que 75% do que a média histórica, é lido somente 10% da tabela de destino e é recalculado a distribuição
    dos dados ao atualizar as métricas do otimizador de consultas
    
*/

------------------------------> Definições de variaveis e controles de ambiente

Set nocount on;

Declare @NomeProcedure varchar(128) = 'ProcProdutos',
        @Etapa varchar(100) = 'Inicio',
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
     @IdExecucao = @IdExecucao OUTPUT

Begin try

------------------------------> Criacao das tabelas temporarias

Set @Etapa = 'Criacao das tabelas temporarias';

--- | Tipo ocorrências

If Object_id('Tempdb..#Produtos') Is not null Drop table #Produtos;
Create table #Produtos (
    IdProduto int,
    Produto varchar(64),
    CodigoReferencia varchar(16)
);

------------------------------> Carga das tabelas temporarias

Set @Etapa = 'Carga das tabelas temporarias';

Declare @IdProduto int = (Select Max(IdProduto) From misitau.dbo.Produtos With(nolock));

Insert into #Produtos (
                       IdProduto,
                       Produto,
                       CodigoReferencia
                       )
Select
    IdProduto,
    Produto,
    CodigoReferencia
From misitau.glo.Produtos
Where
    IdProduto > isnull(@IdProduto, 0);

Set @LinhasOrigem = @@RowCount;

------------------------------> Criacao de indices

Set @Etapa = 'Criacao de indices';

/* Cria index não clusterizado */
Create nonclustered index IxProdutos on #Produtos (IdProduto);


------------------------------> Persistencia final

Set @Etapa = 'Persistencia final';

--- | Tabela fisica

Insert into misitau.dbo.Produtos (
                                IdProduto,
                                Produto,
                                CodigoReferencia
                                )
Select
    IdProduto,
    Produto,
    CodigoReferencia
From #Produtos a With(nolock)
Where
    Not exists (Select 1
                From misitau.dbo.Produtos b With(nolock)
                Where
                    a.IdProduto = b.IdProduto);

Set @LinhasInseridas = @@RowCount;
Set @LinhasTotaisDestino = @LinhasInseridas;

Set @MediaUltimasExecucoes = (Select 
                                avg (LinhasTotaisDestino)
                              From (Select top 10
                                        LinhasTotaisDestino
                                    From misitau.log.ControleVolumes With(nolock)
                                    Where   
                                        NomeTabelaDestino = 'dbo.Produtos'
                                    Order by
                                        IdControleVolume desc) a);

Set @MediaVolumetria = (Select
                            avg (LinhasTotaisDestino)
                        From (Select
                                Max(LinhasTotaisDestino) as LinhasTotaisDestino
                              From
                                misitau.log.ControleVolumes With(nolock)
                              Where
                                NomeTabelaDestino = 'dbo.Produtos'
                              Group by
                                Convert(date, DataExecucao)) a);

If @LinhasTotaisDestino > @MediaUltimasExecucoes and @LinhasTotaisDestino >= @MediaVolumetria * 0.75
Begin
    Update Statistics misitau.dbo.Produtos With Sample 10 Percent;
End;

Set @DataHoraFim = Dateadd(hour,-3,Getdate());

/* Grava volumetria controles de log */
Exec misitau.[log].ProcControles
     @TipoLog = 'Volumetria',
     @IdExecucao = @IdExecucao,
     @NomeTabelaOrigem = 'glo.Produtos',
     @NomeTabelaDestino = 'dbo.Produtos',
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