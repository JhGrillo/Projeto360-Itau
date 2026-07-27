Create or Alter procedure dbo.ProcAcordosParcelasPagar as

------------------------------> Descrição da procedure

/*
    Padrão de escrita: PascalCase
    Nome: ProcAcordosParcelasPagar
    DataCriação: 27/07/2026
    Criado por: João Henrique Cavalheiro Grillo
    DataAtualização:
    Atualizado por:

    Descrição atualização: (Data, Atualizado por, Descrição, git)
*/

------------------------------> Definições de variaveis e controles de ambiente

Set Nocount On;

Declare @NomeProcedure varchar(128) = 'ProcAcordosParcelasPagar',
        @Etapa varchar(100) = 'Inicio',
        @IdAcordo varchar(max),
        @SQLAcordosParcelasPagar nvarchar(max),
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

--- | Acordos parcelas pagar

If Object_id('Tempdb..#AcordosParcelasPagar') Is not null Drop table #AcordosParcelasPagar;
Create table #AcordosParcelasPagar (
    IdAcordoParcelaPagar int,
    IdAcordo int,
    NumeroParcela tinyint,
    DataVencimento date,
    Valor money,
    DataPagamento date,
    ValorPago money
);

------------------------------> Carga das tabelas temporarias

Set @Etapa = 'Carga das tabelas temporarias';

--- | Insere novos Acordos de Parcelas a Pagar na tabela

Set @IdAcordo = (Select 
                    String_agg(Convert(varchar(max),IdAcordo),',') 
                From misitau.dbo.Acordos a With(nolock)
                Where
                    Not exists (Select 1
                                From misitau.dbo.AcordosParcelasPagar b With(nolock)
                                Where
                                    a.IdAcordo = b.IdAcordo
                                    and b.DataPagamento is not null));
 

Set @SQLAcordosParcelasPagar = N'
Insert into #AcordosParcelasPagar
Select
    IdAcordoParcelaPagar,
    IdAcordo,
    NumeroParcela,
    DataVencimento,
    Valor,
    DataPagamento,
    ValorPago
From misitau.cob.AcordosParcelasPagar a
Where
    IdAcordo in (' + @IdAcordo + ')
    and Not exists (Select 1
                    From misitau.dbo.AcordosParcelasPagar b With(nolock)
                    Where
                        a.IdAcordoParcelaPagar = b.IdAcordoParcelaPagar
                        and Isnull(a.DataPagamento,''1900-01-01'') = Isnull(b.DataPagamento,''1900-01-01''))';

Exec sp_executesql @SQLAcordosParcelasPagar;

Set @LinhasOrigem = @@RowCount;

------------------------------> Criacao de índices

Set @Etapa = 'Criacao de indices';

/* Cria index não clusterizado */

Create nonclustered index IxAcordosParcelasPagar on #AcordosParcelasPagar (IdAcordoParcelaPagar);

------------------------------> Persistencia final

Set @Etapa = 'Persistencia final';

--- | Tabela fisica

Insert into misitau.dbo.AcordosParcelasPagar
Select distinct
    IdAcordoParcelaPagar,
    IdAcordo,
    NumeroParcela,
    DataVencimento,
    Valor,
    DataPagamento,
    ValorPago
From #AcordosParcelasPagar a With(nolock)
Where
    Not exists (Select 1
                From misitau.dbo.AcordosParcelasPagar b With(nolock)
                Where
                    a.IdAcordoParcelaPagar = b.IdAcordoParcelaPagar);

Set @LinhasInseridas = @@RowCount;

------------------------------> Atualizacao de dados

Set @Etapa = 'Atualizacao de dados';

--- | Atualiza campos da tabela fisica

Update a
Set a.DataPagamento = b.DataPagamento,
    a.ValorPago = b.ValorPago
From misitau.dbo.AcordosParcelasPagar a with(nolock)
Inner join #AcordosParcelasPagar b With(nolock) on a.IdAcordoParcelaPagar = b.IdAcordoParcelaPagar
Where
    b.DataPagamento is not null
    and a.DataPagamento is null;

Set @LinhasAtualizadas = @@RowCount;
Set @LinhasTotaisDestino = @LinhasInseridas + @LinhasAtualizadas;
Set @DataHoraFim = Dateadd(hour,-3,Getdate());

/* Grava volumetria controles de log */
Exec misitau.[log].ProcControles
    @TipoLog = 'Volumetria',
    @IdExecucao = @IdExecucao,
    @NomeTabelaOrigem = 'cob.AcordosParcelasPagar',
    @NomeTabelaDestino = 'dbo.AcordosParcelasPagar',
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