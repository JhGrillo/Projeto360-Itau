Create or Alter procedure itau.ProcFunilUnique360 as

------------------------------> Descrição da procedure

/*
    Padrão de escrita: PascalCase
    Nome: ProcFunilUnique360
    DataCriação: 27/08/2026
    Criado por: João Henrique Cavalheiro Grillo
    DataAtualização: 08/10/2026
    Atualizado por: João Henrique Cavalheiro Grillo

    Descrição atualização: (Data, Atualizado por, Descrição, git)

	06/10/2026 Leonardo Matheus Talarico: Ao inserir as informações na tabela final do FunilUnique360 os primeiros dias uteis não eram inseridos devido a um erro de lógica, que desconsiderava
	qualquer data menor ou igual ao dia 01 e com 00:00 horas. Ou seja, o primeiro loop nunca era marcado, pois as datas observadas eram sempre maiores que o seu horário.

	08/10/2026 João Henrique Cavalheiro Grillo:
	- Campos adicionados, valores de base (Regularizacao e SaldoVencido), valores de acordos, vencimentos e pagamentos (Valor e Regularização).
*/

------------------------------> Definições de variaveis e controles de ambiente

Set Nocount On;

Declare @NomeProcedure varchar(128) = 'ProcFunilUnique360',
        @Etapa varchar(100) = 'Inicio',
        @IdExecucao int,
        @DataHoraInicio datetime = Getdate(),
        @DataHoraFim datetime,
        @MensagemErro varchar(max),
        @NumeroErro int,
        @LinhaErro int,
		@DataIni datetime,
		@DataFim datetime;

--/* Inicia o controle de logs */
Exec dbDataDwItau.[log].ProcControles
    @TipoLog = 'Execucao',
    @NomeProcedure = @NomeProcedure,
    @DataHoraInicio = @DataHoraInicio,
    @StatusExecucao = 'Executando',
    @IdExecucao = @IdExecucao OUTPUT;

Begin Try

--------------------------------> Criacao de tabelas temporarias

Set @Etapa = 'Criacao das tabelas temporarias';

--- | AnaliticoUnique

If Object_id('Tempdb..#AnaliticoUnique') Is not null Drop table #AnaliticoUnique;
Create table #AnaliticoUnique (
	IdDevedor int,
	CodigoReferencia smallint,
	Carteira varchar(64),
	Produto varchar(64),
	SubProduto varchar(64),
	Cluster varchar(4),
	FaixaAtraso varchar(32),
	FaixaValor varchar(32),
	Base datetime,
	ValorRegularizacao money,
	ValorSaldoVencido money,
	Mailing datetime,
	TrabalhadoDiscador datetime,
	TrabalhadoDiscadorDigital datetime,
	TrabalhadoCRM datetime,
	Atendido datetime,
	CPC datetime,
	Acordo datetime,
	ValorAcordo money,
	ValorAcordoRegularizacao money,
	Vencimento datetime,
	ValorVencimento money,
	ValorVencimentoRegularizacao money,
	Pagamento datetime,
	ValorPagamento money,
	ValorPagamentoRegularizacao money
);

------------------------------> Carga das tabelas temporarias

Set @Etapa = 'Carga das tabelas temporarias';

Set @DataIni = (Select
					Dateadd(mm,Datediff(mm, 0, Isnull(Max(DataHoraFim),Getdate())),0)
				From dbDataDwItau.log.ControleExecucoes With(nolock)
				Where
					NomeProcedure = 'ProcFunilUnique360'
					and StatusExecucao = 'Concluida');

Set @DataFim = (Select
					Isnull(Max(DataHoraFim),Getdate())
				From dbDataDwItau.log.ControleExecucoes With(nolock)
				Where
					NomeProcedure = 'ProcFunilUnique360'
					and StatusExecucao = 'Concluida');

With BaseUnique as (

	Select
		IdDevedor,	
		CodigoReferencia,
		Carteira,
		Produto,
		SubProduto,
		Cluster,
		Max(FaixaAtraso) as FaixaAtraso,	
		Max(FaixaValor) as FaixaValor,
		Min(Data) as Base,
		Max(ValorRegularizacao) as ValorRegularizacao,
		Max(SaldoVencido) as SaldoVencido
	From dbDataDwItau.itau.Base360 a With(nolock)
	Where
		Data between @DataIni and @DataFim
		and CodigoReferencia = 777
	Group by
		IdDevedor,
		CodigoReferencia,
		Carteira,
		Produto,
		SubProduto,
		Cluster

),

MailingUnique as (

	Select
		b.IdDevedor,
		b.CodigoReferencia,
		b.Carteira,
		b.Produto,
		b.SubProduto,
		b.Cluster,
		Max(b.FaixaAtraso) as FaixaAtraso,	
		Max(b.FaixaValor) as FaixaValor,
		Min(a.Data) as Mailing
	From dbDataDwItau.itau.BaseMailing360 a With(nolock)
	Inner join dbDataDwItau.itau.Base360 b With(nolock) on a.IdBase = b.IdBase
	Where
		a.Data between @DataIni and @DataFim
		and a.IdRetirada is null
		and CodigoReferencia = 777
	Group by
		b.IdDevedor,
		b.CodigoReferencia,
		b.Carteira,
		b.Produto,
		b.SubProduto,
		b.Cluster

),

DiscadorUnique as (

	Select
		b.IdDevedor,
		b.CodigoReferencia,
		b.Carteira,
		b.Produto,
		b.SubProduto,
		b.Cluster,
		Max(b.FaixaAtraso) as FaixaAtraso,	
		Max(b.FaixaValor) as FaixaValor,
		Min(a.Data) as TrabalhadoDiscador
	From dbDataDwItau.itau.Discador360 a With(nolock)
	Inner join dbDataDwItau.itau.Base360 b With(nolock) on a.IdBase = b.IdBase
	Where
		a.Data between @DataIni and @DataFim
		and CodigoReferencia = 777
	Group by
		b.IdDevedor,
		b.CodigoReferencia,
		b.Carteira,
		b.Produto,
		b.SubProduto,
		b.Cluster

),

DiscadorDigitalUnique as (

	Select
		b.IdDevedor,
		b.CodigoReferencia,
		b.Carteira,
		b.Produto,
		b.SubProduto,
		b.Cluster,
		Max(b.FaixaAtraso) as FaixaAtraso,	
		Max(b.FaixaValor) as FaixaValor,
		Min(a.Data) as TrabalhadoDiscadorDigital
	From dbDataDwItau.itau.DiscadorDigital360 a With(nolock)
	Inner join dbDataDwItau.itau.Base360 b With(nolock) on a.IdBase = b.IdBase
	Where
		a.Data between @DataIni and @DataFim
		and a.CodigoReferencia = 777
	Group by
		b.IdDevedor,
		b.CodigoReferencia,
		b.Carteira,
		b.Produto,
		b.SubProduto,
		b.Cluster

),

CRMUnique as (

	Select
		b.IdDevedor,
		b.CodigoReferencia,
		b.Carteira,
		b.Produto,
		b.SubProduto,
		b.Cluster,
		Max(b.FaixaAtraso) as FaixaAtraso,	
		Max(b.FaixaValor) as FaixaValor,
		Min(a.Data) as TrabalhadoCRM,
		Min(Case when a.Atendimento = 1 then a.Data end) as Atendido,
		Min(Case when a.CPC = 1 then a.Data end) as CPC
	From dbDataDwItau.itau.CRM360 a With(nolock)
	Inner join dbDataDwItau.itau.Base360 b With(nolock) on a.IdBase = b.IdBase
	Where
		a.Data between @DataIni and @DataFim
		and CodigoReferencia = 777
	Group by
		b.IdDevedor,
		b.CodigoReferencia,
		b.Carteira,
		b.Produto,
		b.SubProduto,
		b.Cluster

),

AcordoUnique as (

	Select
		b.IdDevedor,
		b.CodigoReferencia,
		b.Carteira,
		b.Produto,
		b.SubProduto,
		b.Cluster,
		Max(b.FaixaAtraso) as FaixaAtraso,	
		Max(b.FaixaValor) as FaixaValor,
		Min(a.Data) as Acordo,
		Sum(a.Valor) as ValorAcordo,
		Max(b.ValorRegularizacao) as ValorAcordoRegularizacao
	From dbDataDwItau.itau.Acordos360 a With(nolock)
	Inner join dbDataDwItau.itau.Base360 b With(nolock) on a.IdBase = b.IdBase
	Where
		a.Data between @DataIni and @DataFim
		and b.CodigoReferencia = 777
		and a.NumeroParcela = 1
	Group by
		b.IdDevedor,
		b.CodigoReferencia,
		b.Carteira,
		b.Produto,
		b.SubProduto,
		b.Cluster

),

VencimentoUnique as (

	Select
		b.IdDevedor,
		b.CodigoReferencia,
		b.Carteira,
		b.Produto,
		b.SubProduto,
		b.Cluster,
		Max(b.FaixaAtraso) as FaixaAtraso,	
		Max(b.FaixaValor) as FaixaValor,
		Min(a.Data) as Vencimento,
		Sum(a.Valor) as ValorVencimento,
		Max(b.ValorRegularizacao) as ValorVencimentoRegularizacao
	From dbDataDwItau.itau.Vencimentos360 a With(nolock)
	Inner join dbDataDwItau.itau.Base360 b With(nolock) on a.IdBase = b.IdBase
	Where
		a.Data between @DataIni and @DataFim
		and b.CodigoReferencia = 777
		and a.NumeroParcela = 1
	Group by
		b.IdDevedor,
		b.CodigoReferencia,
		b.Carteira,
		b.Produto,
		b.SubProduto,
		b.Cluster

),

PagamentoUnique as (

	Select
		b.IdDevedor,
		b.CodigoReferencia,
		b.Carteira,
		b.Produto,
		b.SubProduto,
		b.Cluster,
		Max(b.FaixaAtraso) as FaixaAtraso,	
		Max(b.FaixaValor) as FaixaValor,
		Min(a.Data) as Pagamento,
		Sum(a.ValorPago) as ValorPagamento,
		Max(b.ValorRegularizacao) as ValorPagamentoRegularizacao
	From dbDataDwItau.itau.Pagamentos360 a With(nolock)
	Inner join dbDataDwItau.itau.Base360 b With(nolock) on a.IdBase = b.IdBase
	Where
		a.Data between @DataIni and @DataFim
		and b.CodigoReferencia = 777
		and a.NumeroParcela = 1
	Group by
		b.IdDevedor,
		b.CodigoReferencia,
		b.Carteira,
		b.Produto,
		b.SubProduto,
		b.Cluster

)

Insert into #AnaliticoUnique
Select
	a.IdDevedor,
	a.CodigoReferencia,
	a.Carteira,
	a.Produto,
	a.SubProduto,
	a.Cluster,
	a.FaixaAtraso,
	a.FaixaValor,
	Convert(date,a.Base) as Base,
	a.ValorRegularizacao,
	a.SaldoVencido,
	Convert(date,b.Mailing) as Mailing,
	Convert(date,c.TrabalhadoDiscador) as TrabalhadoDiscador,
	Convert(date,d.TrabalhadoDiscadorDigital) as TrabalhadoDiscadorDigital,
	Convert(date,e.TrabalhadoCRM) as TrabalhadoCRM,
	Convert(date,e.Atendido) as Atendido,
	Convert(date,e.CPC) as CPC,
	Convert(date,f.Acordo) as Acordo,
	f.ValorAcordo as ValorAcordo,
	f.ValorAcordoRegularizacao as ValorAcordoRegularizacao,
	Convert(date,Isnull(g.Vencimento,h.Pagamento)) as Vencimento,
	Isnull(g.ValorVencimento,h.ValorPagamento) as ValorVencimento,
	Isnull(g.ValorVencimentoRegularizacao,h.ValorPagamentoRegularizacao) as ValorVencimentoRegularizacao,
	Convert(date,h.Pagamento) as Pagamento,
	h.ValorPagamento as ValorPagamento,
	h.ValorPagamentoRegularizacao as ValorPagamentoRegularizacao
From BaseUnique a
Left join MailingUnique b on a.IdDevedor = b.IdDevedor
							  and a.CodigoReferencia = b.CodigoReferencia
							  and a.Carteira = b.Carteira
							  and a.Produto = b.Produto
							  and a.SubProduto = b.SubProduto
							  and a.Cluster = b.Cluster
							  and a.FaixaAtraso = b.FaixaAtraso
							  and a.FaixaValor = b.FaixaValor
Left join DiscadorUnique c on a.IdDevedor = c.IdDevedor
							  and a.CodigoReferencia = c.CodigoReferencia
							  and a.Carteira = c.Carteira
							  and a.Produto = c.Produto
							  and a.SubProduto = c.SubProduto
							  and a.Cluster = c.Cluster
							  and a.FaixaAtraso = c.FaixaAtraso
							  and a.FaixaValor = c.FaixaValor
Left join DiscadorDigitalUnique d on a.IdDevedor = d.IdDevedor
									 and a.CodigoReferencia = d.CodigoReferencia
									 and a.Carteira = d.Carteira
									 and a.Produto = d.Produto
									 and a.SubProduto = d.SubProduto
									 and a.Cluster = d.Cluster
									 and a.FaixaAtraso = d.FaixaAtraso
									 and a.FaixaValor = d.FaixaValor
Left join CRMUnique e on a.IdDevedor = e.IdDevedor
						 and a.CodigoReferencia = e.CodigoReferencia
						 and a.Carteira = e.Carteira
						 and a.Produto = e.Produto
						 and a.SubProduto = e.SubProduto
						 and a.Cluster = e.Cluster
						 and a.FaixaAtraso = e.FaixaAtraso
						 and a.FaixaValor = e.FaixaValor
Left join AcordoUnique f on a.IdDevedor = f.IdDevedor
							and a.CodigoReferencia = f.CodigoReferencia
						    and a.Carteira = f.Carteira
						    and a.Produto = f.Produto
						    and a.SubProduto = f.SubProduto
						    and a.Cluster = f.Cluster
						    and a.FaixaAtraso = f.FaixaAtraso
						    and a.FaixaValor = f.FaixaValor
Left join VencimentoUnique g on a.IdDevedor = g.IdDevedor
							   and a.CodigoReferencia = g.CodigoReferencia
						       and a.Carteira = g.Carteira
						       and a.Produto = g.Produto
						       and a.SubProduto = g.SubProduto
						       and a.Cluster = g.Cluster
						       and a.FaixaAtraso = g.FaixaAtraso
						       and a.FaixaValor = g.FaixaValor
Left join PagamentoUnique h on a.IdDevedor = h.IdDevedor
							   and a.CodigoReferencia = h.CodigoReferencia
						       and a.Carteira = h.Carteira
						       and a.Produto = h.Produto
						       and a.SubProduto = h.SubProduto
						       and a.Cluster = h.Cluster
						       and a.FaixaAtraso = h.FaixaAtraso
						       and a.FaixaValor = h.FaixaValor;

------------------------------> Persistência final

Set @Etapa = 'Persistência final';

Declare @DataIniLoop datetime = @DataIni,
		@DataFimLoop datetime = @DataFim,
		@DiaUtil int;

Delete from dbDataDwItau.itau.FunilUnique360 Where Data between @DataIni and @DataFim;


While @DataIniLoop <= @DataFimLoop
Begin

	
	Set @DiaUtil = (Select DiaUtil From [srv-dbbi].dw.geral.Calendario With(nolock) Where Data = @DataIniLoop);

	Insert into itau.FunilUnique360 (
										Ano,
										Mes,
										Data,
										DiaUtil,
										CodigoReferencia,
										Carteira,
										Produto,
										SubProduto,
										Cluster,
										FaixaAtraso,
										FaixaValor,
										Base,
										ValorRegularizacao,
										ValorSaldoVencido,
										Mailing,
										Trabalhado,
										Atendido,
										CPC,
										Acordo,
										ValorAcordo,
										ValorAcordoRegularizacao,
										Vencimento,
										ValorVencimento,
										ValorVencimentoRegularizacao,
										Pagamento,
										ValorPagamento,
										ValorPagamentoRegularizacao
									)
	Select
		Year(@DataIniLoop) as Ano,
		Month(@DataIniLoop) as Mes,
		@DataIniLoop as Data,
		@DiaUtil as DiaUtil,
		CodigoReferencia,
		Carteira,
		Produto,
		SubProduto,
		Cluster,
		FaixaAtraso,
		FaixaValor,
		Count(Case when Base <= @DataIniLoop then IdDevedor end) as Base,
		Sum(Case when Base <= @DataIniLoop then ValorRegularizacao end) as ValorRegularizacao,
		Sum(Case when Base <= @DataIniLoop then ValorSaldoVencido end) as ValorSaldoVencido,
		Count(Case when Mailing <= @DataIniLoop or TrabalhadoDiscador <= @DataIniLoop or TrabalhadoDiscadorDigital <= @DataIniLoop or TrabalhadoCRM <= @DataIniLoop then IdDevedor end) as Mailing,
		Count(Case when TrabalhadoDiscador <= @DataIniLoop or TrabalhadoDiscadorDigital <= @DataIniLoop or TrabalhadoCRM <= @DataIniLoop then IdDevedor end) as Trabalhado,
		Count(Case when Atendido <= @DataIniLoop then IdDevedor end) as Atendido,
		Count(Case when CPC <= @DataIniLoop then IdDevedor end) as CPC,
		Count(Case when Acordo <= @DataIniLoop then IdDevedor end) as Acordo,
		Sum(Case when Acordo <= @DataIniLoop then ValorAcordo end) as ValorAcordo,
		Sum(Case when Acordo <= @DataIniLoop then ValorAcordoRegularizacao end) as ValorAcordoRegularizacao,
		Count(Case when Vencimento <= @DataIniLoop then IdDevedor end) as Vencimento,
		Count(Case when Vencimento <= @DataIniLoop then ValorVencimento end) as ValorVencimento,
		Count(Case when Vencimento <= @DataIniLoop then ValorVencimentoRegularizacao end) as ValorVencimentoRegularizacao,
		Count(Case when Pagamento <= @DataIniLoop then IdDevedor end) as Pagamento,
		Count(Case when Pagamento <= @DataIniLoop then ValorPagamento end) as ValorPagamento,
		Count(Case when Pagamento <= @DataIniLoop then ValorPagamentoRegularizacao end) as ValorPagamentoRegularizacao
	From #AnaliticoUnique
	Group by
		CodigoReferencia,
		Carteira,
		Produto,
		SubProduto,
		Cluster,
		FaixaAtraso,
		FaixaValor;

Set @DataHoraFim = Getdate();

/* Grava volumetria controles de log */
Exec dbDataDwItau.[log].ProcControles
    @TipoLog = 'Volumetria',
    @IdExecucao = @IdExecucao,
    @NomeTabelaDestino = 'itau.FunilUnique360';

/* Finaliza execução controles de log concluido */
Exec dbDataDwItau.[log].ProcControles
    @TipoLog = 'Atualizacao',
    @IdExecucao = @IdExecucao,
    @DataHoraFim = @DataHoraFim,
    @StatusExecucao = 'Concluida';

Set @DataIniLoop += 1;
end;

end try
begin catch

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

end catch;