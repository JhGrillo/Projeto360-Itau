Create procedure or Alter Procedure itau.ProcAnaliticoFunilDia360 as

------------------------------> Descrição da procedure

/*
    Padrão de escrita: PascalCase
    Nome: ProcAnaliticoFunilDia360
    DataCriação: 21/08/2026
    Criado por: João Henrique Cavalheiro Grillo
    DataAtualização: 07/10/2026
    Atualizado por: João Henrique Cavalheiro Grillo

    Descrição atualização: (Data, Atualizado por, Descrição, git)

	07/10/2026 João Henrique Cavalheiro Grillo: 
	- Implementada regra de execução por horário: antes das 12h processa o dia anterior; após as 12h processa o dia atual.
	- Adicionados campos de acordo, vencimento e pagamento da 1ª parcela, atendendo à regra de negócio da carteira (WO avalia valor de regularização; Ativo avalia valor da 1ª parcela acordo e valor de regularização).
	- Refatorada a lógica principal utilizando CROSS APPLY para otimizar o desempenho e melhorar a legibilidade do código.
*/

------------------------------> Definições de variaveis e controles de ambiente

Set Nocount off;

Declare @NomeProcedure varchar(128) = 'ProcAnaliticoFunilDia360',
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

--------------------------------> Criacao de tabelas temporarias

Set @Etapa = 'Criacao das tabelas temporarias';

--- | Analitico

If Object_id('Tempdb..#Analitico') Is not null Drop table #Analitico;
Create table #Analitico (
	Data datetime,
	IdDevedor int,
	CodigoReferencia smallint,
	Carteira varchar(64),
	Produto varchar(64),
	SubProduto varchar(64),
	Cluster varchar(4),
	FaixaAtraso varchar(32),
	ValorRegularizacao money,
	FaixaValor varchar(32),
	Mailing int,
	DiscagensDiscador int,
	DiscagensDigital int,
	Trabalhado int,
	Atendido int,
	CPC int,
	Acordo int,
	ValorAcordo money,
	ValorAcordoRegularizacao money,
	Vencimento int,
	ValorVencimento money,
	ValorVencimentoRegularizacao money,
	Pagamento int,
	ValorPagamento money,
	ValorPagamentoRegularizacao money
);

------------------------------> Carga das tabelas temporarias

Set @Etapa = 'Carga das tabelas temporarias';
Set @DataIni = (Select
					Max(Convert(date,Case
										when Convert(time,Getdate()) <= '12:00' then Dateadd(day,-1,DataHoraFim)
										else DataHoraFim
									end))
					From dbDataDwItau.log.ControleExecucoes With(nolock) 
					Where 
						NomeProcedure = 'ProcAnaliticoFunilDia360'
						and StatusExecucao = 'Concluida');
Set @DataFim = @DataIni + '23:59';

--- | Analitico

/* Agregação de discador */
With DiscadorCTE as (
	Select
		IdBase,
		Count(IdDiscador) as DiscagensDiscador
	From dbDataDwItau.itau.Discador360 With(nolock)
	Where
		Data between @DataIni and @DataFim
	Group by
		IdBase
),

/* Agregação do CRM */
DiscadorDigitalCTE as (
	Select
		IdBase,
		Count(IdDiscadorDigital) as DiscagensDigital
	From dbDataDwItau.itau.DiscadorDigital360 With(nolock)
	Where
		Data between @DataIni and @DataFim
	Group by
		IdBase
),

/* Agregação do CRM */
CRMCTE as (
	Select
		IdBase,
		Max(Atendimento) as Atendimento,
		Max(CPC) as CPC,
		Max(Acordo) as Acordo
	From dbDataDwItau.itau.CRM360 With(nolock)
	Where
		Data between @DataIni and @DataFim
	Group by
		IdBase
),

/* Agregação dos acordos */
AcordosCTE as (
	Select distinct
		IdBase,
		Sum(Valor) as ValorAcordo
	From dbDataDwItau.itau.Acordos360 With(nolock)
	Where
		Data between @DataIni and @DataFim
		and NumeroParcela = 1
	Group by
		IdBase
),

/* Agregação dos vencimentos */
VencimentosCTE as (
	Select distinct
		IdBase,
		Sum(Valor) as ValorAcordo
	From dbDataDwItau.itau.Vencimentos360 With(nolock)
	Where
		Data between @DataIni and @DataFim
		and NumeroParcela = 1
		and (DataCancelamento is null
		or Convert(date,DataCancelamento) >= Data)
	Group by
		IdBase
),

/* Agregação dos pagamentos */
PagamentosCTE as (
	Select distinct
		IdBase,
		Sum(ValorPago) as ValorPago
	From dbDataDwItau.itau.Pagamentos360 With(nolock)
	Where
		Data between @DataIni and @DataFim
	Group by
		IdBase
),

/* Agregação do mailing */
MailingCTE as (
	Select distinct
		IdBase,
		IdRetirada
	From dbDataDwItau.itau.BaseMailing360 With(nolock)
	Where
		Data between @DataIni and @DataFim
)

Insert into #Analitico
Select
	Base.Data, 
	Base.IdDevedor,
	Base.CodigoReferencia,
	Base.Carteira, 
	Base.Produto, 
	Base.SubProduto, 
	Base.Cluster,  
	Base.FaixaAtraso, 
	Base.ValorRegularizacao, 
	Base.FaixaValor, 
	Calculos.Mailing,
	Discador.DiscagensDiscador,
	DiscadorDigital.DiscagensDigital,
	Calculos.Trabalhado,
	Calculos.Atendido,
	Calculos.CPC,
	Calculos.Acordo,
	Calculos.ValorAcordo,
	Calculos.ValorAcordoRegularizacao,
	Calculos.Vencimento,
	Calculos.ValorVencimento,
	Calculos.ValorVencimentoRegularizacao,
	Calculos.Pagamento,
	Calculos.ValorPagamento,
	Calculos.VaorPagamentoRegularizacao
From dbDataDwItau.itau.Base360 Base With(nolock)
Left join DiscadorCTE Discador on Base.IdBase = Discador.IdBase
Left join DiscadorDigitalCTE DiscadorDigital on Base.IdBase = DiscadorDigital.IdBase
Left join CRMCTE CRM on Base.IdBase = CRM.IdBase
Left join AcordosCTE Acordos on Base.IdBase = Acordos.IdBase
Left join VencimentosCTE Vencimentos on Base.IdBase = Vencimentos.IdBase
Left join PagamentosCTE Pagamentos on Base.IdBase = Pagamentos.IdBase
Left join MailingCTE Mailing on Base.IdBase = Mailing.IdBase
Cross Apply(Select
				Case
					when Mailing.IdBase is null then 0
					when Mailing.IdRetirada > 0 and Discador.IdBase is null then 0
					else 1
				end as Mailing,
				Case when Discador.DiscagensDiscador > 0 or DiscadorDigital.DiscagensDigital > 0 or CRM.IdBase is not null or Acordos.IdBase is not null then 1 end as Trabalhado,
				Case when Acordos.IdBase is not null then 1 else CRM.Atendimento end as Atendido,
				Case when Acordos.IdBase is not null then 1 else CRM.CPC end as CPC,
				Case when Acordos.IdBase is not null then 1 else CRM.Acordo end as Acordo,
				Case when Acordos.IdBase is not null then Acordos.ValorAcordo end as ValorAcordo,
				Case when Acordos.IdBase is not null then Base.ValorRegularizacao end as ValorAcordoRegularizacao,
				Case when Vencimentos.IdBase is not null or Pagamentos.IdBase is not null then 1 end as Vencimento,
				Case when Vencimentos.IdBase is not null or Pagamentos.IdBase is not null then Isnull(Vencimentos.ValorAcordo,Pagamentos.ValorPago) end as ValorVencimento,
				Case when Vencimentos.IdBase is not null or Pagamentos.IdBase is not null then Base.ValorRegularizacao end as ValorVencimentoRegularizacao,
				Case when Pagamentos.IdBase is not null then 1 end as Pagamento,
				Case when Pagamentos.IdBase is not null then Pagamentos.ValorPago end  as ValorPagamento,
				Case when Pagamentos.IdBase is not null then Base.ValorRegularizacao end VaorPagamentoRegularizacao) as Calculos

Where
	Base.Data between @DataIni and @DataFim
	and Base.CodigoReferencia = 777;

------------------------------> Persistencia final

Set @Etapa = 'Persistencia final';

--- | Tabela fisica

If Object_id('dbDataDwItau.itau.AnaliticoFunilDia360') is not null Drop table dbDataDwItau.itau.AnaliticoFunilDia360;
Select
	Data,
	IdDevedor,
	CodigoReferencia,
	Carteira,
	Produto,
	SubProduto,
	Cluster,
	Mailing,
	Max(FaixaAtraso) as FaixaAtraso,
	Sum(ValorRegularizacao) as ValorRegularizacao,
	Max(FaixaValor) as FaixaValor,
	Sum(Distinct DiscagensDiscador) as DiscagensDiscador,
	Sum(Distinct DiscagensDigital) as DiscagensDigital,
	Max(Trabalhado) as Trabalhado,
	Max(Atendido) as Atendido,
	Max(CPC) as CPC,
	Max(Acordo) as Acordo,
	Sum(ValorAcordo) as ValorAcordo, 
	Sum(ValorAcordoRegularizacao) as ValorAcordoRegularizacao,
	Max(Vencimento) as Vencimento,
	Sum(ValorVencimento) as ValorVencimento,
	Sum(ValorVencimentoRegularizacao) as ValorVencimentoRegularizacao,
	Max(Pagamento) as Pagamento,
	Sum(ValorPagamento) as ValorPagamento,
	Sum(ValorPagamentoRegularizacao) as ValorPagamentoRegularizacao
into dbDataDwItau.itau.AnaliticoFunilDia360
From #Analitico
Group by
	Data,
	IdDevedor,
	CodigoReferencia,
	Carteira,
	Produto,
	SubProduto,
	Cluster,
	Mailing;

Set @LinhasTotaisDestino = @LinhasInseridas;
Set @DataHoraFim = Getdate();

/* Grava volumetria controles de log */
Exec dbDataDwItau.[log].ProcControles
    @TipoLog = 'Volumetria',
    @IdExecucao = @IdExecucao,
    @NomeTabelaDestino = 'itau.AnaliticoFunilDia360',
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