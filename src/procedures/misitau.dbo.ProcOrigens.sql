
Create or Alter Procedure dbo.ProcOrigens as 

------------------------------> Descrição da procedure

/*
    Padrão de escrita: PascalCase
    Nome: ProcOrigens
    DataCriação: 27/07/2026
    Criado por: Leonardo Matheus talarico
    DataAtualização:
    Atualizado por:

    Descrição atualização: (Data, Atualizado por, Descrição, git)
*/

------------------------------> Definições de variaveis e controles de ambiente

Set nocount on;

Declare @NomeProcedure varchar(128) = 'ProcOrigens',
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
     @IdExecucao = @IdExecucao OUTPUT

Begin try

------------------------------> Criacao das tabelas temporarias

Set @Etapa = 'Criacao das tabelas temporarias';

--- | Tipo ocorrências

If Object_id('Tempdb..#Origens') Is not null Drop table #Origens;
Create table #Origens (
    IdOrigem int,
    Origem varchar(64)
);

------------------------------> Carga das tabelas temporarias

Set @Etapa = 'Carga das tabelas temporarias';

Declare @IdOrigem int = (Select Max(IdOrigem) From misitau.dbo.Origens With(nolock));

Insert into #Origens (
                       IdOrigem,
                       Origem
                       )
Select
    IdOrigem,
    Origem
From misitau.glo.Origens
Where
    IdOrigem > isnull(@IdOrigem, 0);

Set @LinhasOrigem = @@RowCount;

------------------------------> Criacao de indices

Set @Etapa = 'Criacao de indices';

/* Cria index não clusterizado */
Create nonclustered index IxOrigens on #Origens (IdOrigem);


------------------------------> Persistencia final

Set @Etapa = 'Persistencia final';

--- | Tabela fisica

Insert into misitau.dbo.Origens (
                               IdOrigem,
                               Origem
                               )
Select
    IdOrigem,
    Origem
From #Origens a With(nolock)
Where
    Not exists (Select 1
                From misitau.dbo.Origens b With(nolock)
                Where
                    a.IdOrigem = b.IdOrigem);

Set @LinhasInseridas = @@RowCount;
Set @LinhasTotaisDestino = @LinhasInseridas;
Set @DataHoraFim = Dateadd(hour,-3,Getdate());

/* Grava volumetria controles de log */
Exec misitau.[log].ProcControles
     @TipoLog = 'Volumetria',
     @IdExecucao = @IdExecucao,
     @NomeTabelaOrigem = 'glo.Origens',
     @NomeTabelaDestino = 'dbo.Origens',
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
