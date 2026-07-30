Create or Alter Procedure dbo.ProcAcordosParcelasPagar as 

------------------------------> Descrição da procedure

/*
    Padrão de escrita: PascalCase
    Nome: ProcAcordosParcelasPagar
    DataCriação: 27/07/2026
    Criado por: João Henrique Cavalheiro Grillo
    DataAtualização:
    Atualizado por:

    Descrição atualização: (Data, Atualizado por, Descrição, git)

	30/07/2026 Leonardo Matheus Talarico: Foi alterado a forma que captura dados, agora se baseia nas datas da penultima execução da dbo.Acordos para seguir a mesma regra
	consultando diretamente na origem, agora a procedure é mais escalavel.
*/

------------------------------> Definições de variaveis e controles de ambiente

Set Nocount On;

Declare @NomeProcedure varchar(128) = 'ProcAcordosParcelasPagar',
        @Etapa varchar(100) = 'Inicio',
        @UltimaAtualizacao datetime,
		@DataPagamento datetime,
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

--- | Origem

If Object_id('Tempdb..#DadosOrigem') Is not null Drop table #DadosOrigem;
Create table #DadosOrigem (
    IdAcordoParcelaPagar int,
    IdAcordo int,
    NumeroParcela tinyint,
    DataVencimento date,
    Valor money,
    DataPagamento date,
    ValorPago money
);

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

--- | Insere novos acordos na tabela de origem

Set @UltimaAtualizacao = (Select 
							Case
								when Datepart(hour,Max(DataHoraInicio)) >= 22 then Max(Dateadd(day,+1,Convert(date,DataHoraInicio)))
								else Max(Convert(date,DataHoraInicio))
							end
						  From misitau.[log].ControleExecucoes a
						  Inner join (Select
										Max(IdExecucao) as IdExecucao
									  From misitau.log.ControleExecucoes
									  Where
										NomeProcedure = 'ProcAcordos'
										and StatusExecucao = 'Concluida') b on a.IdExecucao < b.IdExecucao
										
                          Where
							NomeProcedure = 'ProcAcordos'
							and StatusExecucao = 'Concluida');

Set @DataPagamento = Case
						when Datepart(dw,@UltimaAtualizacao) = 2 then Convert(date,Dateadd(day,-3,@UltimaAtualizacao))
						else Convert(date,Dateadd(day,-1,@UltimaAtualizacao))
					 end;

With AcordosCTE as (
	Select
		IdAcordo
	From misitau.cob.Acordos b
	Where
		DataInclusao >= @UltimaAtualizacao
		or DataCancelamento >= @UltimaAtualizacao
		or DataAprovacaoProposta >= @UltimaAtualizacao
) 

Insert into #DadosOrigem (
					IdAcordoParcelaPagar,
                    IdAcordo,
                    NumeroParcela,
                    DataVencimento,
                    Valor,
                    DataPagamento,
                    ValorPago
				)
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
	Exists (Select 1
			From AcordosCTE b
			Where
				a.IdAcordo = b.IdAcordo)
union all

Select
	IdAcordoParcelaPagar,
    IdAcordo,
    NumeroParcela,
    DataVencimento,
    Valor,
    DataPagamento,
    ValorPago
From misitau.cob.AcordosParcelasPagar
Where
    DataPagamento = @DataPagamento
    or DataVencimento between @UltimaAtualizacao and Convert(date,Dateadd(hour,-3,Getdate()));

/* Cria index clusterizado 
Obs: Este index é criado fora da etapa de index devido a necessidade de performance no comparativo abaixo.
*/
Create nonclustered Index IxAcordosParcelasPagar on #DadosOrigem (IdAcordo);
 
--- | Acordos Parcelas Pagar

Insert into #AcordosParcelasPagar (
								    IdAcordoParcelaPagar,
                                    IdAcordo,
                                    NumeroParcela,
                                    DataVencimento,
                                    Valor,
                                    DataPagamento,
                                    ValorPago
							    )
Select
    IdAcordoParcelaPagar,
    IdAcordo,
    NumeroParcela,
    DataVencimento,
    Valor,
    DataPagamento,
    ValorPago
From #DadosOrigem a
Where
    Not exists (Select 1
                    From misitau.dbo.AcordosParcelasPagar b With(nolock)
                    Where
                        a.IdAcordoParcelaPagar = b.IdAcordoParcelaPagar)

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
                    a.IdAcordoParcelaPagar = b.IdAcordoParcelaPagar
                    and Isnull(a.DataPagamento,'1900-01-01') = Isnull(b.DataPagamento,'1900-01-01'));

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