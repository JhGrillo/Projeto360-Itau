
Create or Alter procedure [itau].[ProcEstratificacaoHistorico360] as

------------------------------> Descrição da procedure

/*
    Padrão de escrita: PascalCase
    Nome: ProcEstratificacaoHistorico360
    DataCriação: 20/10/2026
    Criado por: João Henrique Cavalheiro Grillo
    DataAtualização: 
    Atualizado por: 

    Descrição atualização: 

*/

------------------------------> Definições de variaveis e controles de ambiente

Set Nocount On;

Declare @NomeProcedure varchar(128) = 'ProcEstratificacao360',
        @Etapa varchar(100) = 'Inicio',
        @IdExecucao int,
        @LinhasOrigem int,
        @LinhasInseridas int,
        @LinhasAtualizadas int,
        @LinhasTotaisDestino int,
        @DataHoraInicio datetime = Getdate(),
        @DataHoraFim datetime,
        @MensagemErro varchar(max),
        @NumeroErro int,
        @LinhaErro int,
		@DataIni datetime,
		@DataFim datetime;

/* Inicia o controle de logs */
Exec dbDataDwItau.[log].ProcControles
    @TipoLog = 'Execucao',
    @NomeProcedure = @NomeProcedure,
    @DataHoraInicio = @DataHoraInicio,
    @StatusExecucao = 'Executando',
    @IdExecucao = @IdExecucao OUTPUT;

Begin Try

------------------------------> Criação de tabelas

--- | Resumo

If Object_id('Tempdb..#Resumo') Is not null Drop table #Resumo;
Create table #Resumo (
	Data datetime,
	CodigoReferencia smallint,
	Carteira varchar(64),
	Produto varchar(64),
	SubProduto varchar(64),
	Cluster varchar(4),
	FaixaAtraso varchar(32),
	FaixaValor varchar(32),
	Base int,
	SaldoVencido money,
	ValorRegularizacao money
);

------------------------------> Insere dados em tabelas

Set @DataIni = Dateadd(mm,Datediff(mm,0,Getdate()),0);
Set @DataFim = Convert(date,Getdate());

--- | Resumo

/* Captura a foto do mês por cada cluster disponivel no contrato */
With Foto as (
	Select
		Min(IdBase) as IdBase,
		IdDevedor,
		IdTitulo
	From dbDataDwItau.itau.Base360 With(nolock)
	Where
		Data between @DataIni and @DataFim
	Group by
		IdDevedor,
		IdTitulo,
		Cluster
),

BaseCTE as (
	Select
		Data,
		IdBase,
		IdDevedor,
		IdTitulo,
		CodigoReferencia,
		Carteira,
		Produto,
		SubProduto,
		Cluster,
		FaixaAtraso,
		SaldoVencido,
		ValorRegularizacao,
		FaixaValor
	From dbDataDwItau.itau.Base360 a With(nolock)
	Where
		Exists (Select 1
				From Foto b
				Where
					a.IdBase = b.IdBase)
),

/* Unifica a visão por devedor */
DevedoresUnificados as (

	Select
		Data,
		IdDevedor,
		CodigoReferencia,
		Carteira,
		Produto,
		SubProduto,
		Cluster,
		Max(FaixaAtraso) as FaixaAtraso,
		Max(FaixaValor) as FaixaValor,
		Sum(SaldoVencido) as SaldoVencido,
		Sum(ValorRegularizacao) as ValorRegularizacao
	From BaseCTE
	Group by
		Data,
		IdDevedor,
		CodigoReferencia,
		Carteira,
		Produto,
		SubProduto,
		Cluster

)

/* Gera o resumo por devedor */
Insert into #Resumo (
					Data,
					CodigoReferencia,
					Carteira,
					Produto,
					SubProduto,
					Cluster,
					FaixaAtraso,
					FaixaValor,
					Base,
					SaldoVencido,
					ValorRegularizacao
					)
Select 
	Data,
	CodigoReferencia,
	Carteira,
	Produto,
	SubProduto,
	Cluster,
	FaixaAtraso,
	FaixaValor,
	Count(distinct IdDevedor) as Base,
	Sum(SaldoVencido) as SaldoVencido,
	Sum(ValorRegularizacao) as ValorRegularizacao
From DevedoresUnificados
Group by
	Data,
	CodigoReferencia,
	Carteira,
	Produto,
	SubProduto,
	Cluster,
	FaixaAtraso,
	FaixaValor;

------------------------------> Persistencia final

--- | Limpa histório de processamento

Delete from dbDataDwItau.itau.EstratificacaoHistorico360 Where Data between @DataIni and @DataFim;

--- | Insert final

Insert into dbDataDwItau.itau.EstratificacaoHistorico360 (
														Data,
														CodigoReferencia,
														Carteira,
														Produto,
														SubProduto,
														Cluster,
														FaixaAtraso,
														FaixaValor,
														Base,
														SaldoVencido,
														ValorRegularizacao
														)
Select
	Data,
	CodigoReferencia,
	Carteira,
	Produto,
	SubProduto,
	Cluster,
	FaixaAtraso,
	FaixaValor,
	Base,
	SaldoVencido,
	ValorRegularizacao
From #Resumo;

Set @LinhasInseridas = @@RowCount;
Set @DataHoraFim = Getdate();

/* Grava volumetria controles de log */
Exec dbDataDwItau.[log].ProcControles
    @TipoLog = 'Volumetria',
    @IdExecucao = @IdExecucao,
    @NomeTabelaDestino = 'itau.EstratificacaoHistorico360',
    @LinhasOrigem = @LinhasOrigem,
    @LinhasInseridas = @LinhasInseridas,
    @LinhasAtualizadas = @LinhasAtualizadas,
    @LinhasTotaisDestino = @LinhasTotaisDestino;

/* Finaliza execução controles de log concluido */
Exec dbDataDwItau.[log].ProcControles
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
Set @DataHoraFim = Getdate();
Exec dbDataDwItau.[log].ProcControles
    @TipoLog = 'Atualizacao',
    @IdExecucao = @IdExecucao,
    @DataHoraFim = @DataHoraFim,
    @StatusExecucao = 'Erro';

/* Execução log erro */
Exec dbDataDwItau.[log].ProcControles
    @TipoLog = 'Erro',
    @IdExecucao = @IdExecucao,
    @NomeProcedure = @NomeProcedure,
    @MensagemErro = @MensagemErro,
    @NumeroErro = @NumeroErro,
    @LinhaErro = @LinhaErro,
    @EtapaErro = @Etapa;

End Catch;