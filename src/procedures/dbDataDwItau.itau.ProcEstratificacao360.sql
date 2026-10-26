Create or Alter procedure itau.ProcEstratificacao360 as

------------------------------> Descrição da procedure

/*
    Padrão de escrita: PascalCase
    Nome: ProcEstratificacao360
    DataCriação: 13/10/2026
    Criado por: João Henrique Cavalheiro Grillo
    DataAtualização: 26/10/2026
    Atualizado por: João Henrique Cavalheiro Grillo  

    Descrição atualização: (Data, Atualizado por, Descrição, git)
	19/10/2026 João Henrique Cavalheiro Grillo: Foi incrementado a segmentação de analise por periodo do contrato, possibilitando ver
	os indicadores abertos em uma janela de 30, 60 e 90 dias.

	20/10/2026 João Henrique Cavalheiro Grillo: Incluido o campo de categoria.

	26/10/2026 João Henrique Cavalheiro Grillo: Incluido segmentação de acordo direto e indireto.

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
		@DataAtual date,
		@Data30Dias date,
		@Data60Dias date,
		@Data90Dias date;

/* Inicia o controle de logs */
Exec dbDataDwItau.[log].ProcControles
    @TipoLog = 'Execucao',
    @NomeProcedure = @NomeProcedure,
    @DataHoraInicio = @DataHoraInicio,
    @StatusExecucao = 'Executando',
    @IdExecucao = @IdExecucao OUTPUT;

Begin Try

------------------------------> Criação de tabelas 

--- | Base ativa

If Object_id('Tempdb..#BaseAtiva') Is not null Drop table #BaseAtiva;Create table #BaseAtiva (
	Periodo varchar(32),
	IdBase int,
	IdDevedor int,
	IdTitulo int,
	CodigoReferencia smallint,
	Carteira varchar(64),
	Produto varchar(64),
	SubProduto varchar(64),
	Cluster varchar(4),
	Categoria varchar(100),
	DataInclusao datetime,
	FaixaAtraso varchar(32),
	SaldoVencido money,
	ValorRegularizacao money,
	FaixaValor varchar(32),
	Mailing int,
	Trabalhado int,
	Atendimento int,
	CPC int,
	Acordo int,
	AcordoDireto int,
	AcordoIndireto int
);

--- | Base unificada

If Object_id('Tempdb..#BaseUnificada') Is not null Drop table #BaseUnificada;
Create table #BaseUnificada (	
	Periodo varchar(32),
	IdDevedor int,
	CodigoReferencia smallint,
	Carteira varchar(64),
	Produto varchar(64),
	SubProduto varchar(64),
	Cluster varchar(4),
	Categoria varchar(100),
	DataInclusao datetime,
	FaixaAtraso varchar(32),
	SaldoVencido money,
	ValorRegularizacao money,
	FaixaValor varchar(32),
	Mailing int,
	Trabalhado int,
	Atendimento int,
	CPC int,
	Acordo int,
	AcordoDireto int,
	AcordoIndireto int
);

------------------------------> Insere dados em tabelas

Set @DataAtual = Getdate();
Set @Data30Dias = Dateadd(day,-30, @DataAtual);
Set @Data60Dias = Dateadd(day,-60, @DataAtual);
Set @Data90Dias = Dateadd(day,-90, @DataAtual);

--- | Base ativa

With BasePrincipal as (
	Select
		a.IdBase,
		a.IdDevedor,
		a.IdTitulo,
		a.CodigoReferencia,
		a.Carteira,
		a.Produto,
		a.SubProduto,
		a.Cluster,
		a.Categoria,
		a.DataInclusao,
		a.FaixaAtraso,
		a.SaldoVencido,
		a.ValorRegularizacao,
		a.FaixaValor,
		Case when b.IdBase is not null and b.IdRetirada is null then 1 end as Mailing
	From dbDataDwItau.itau.Base360 a With(nolock)
	Left join dbDataDwItau.itau.BaseMailing360 b With(nolock) on a.IdBase = b.IdBase
	Where
		a.Data >= @DataAtual
		and a.CodigoReferencia = 777
),

DiscadorAgregado as (
		
	Select
		IdDevedor, 
		IdTitulo, 
		'01. 30 Dias' as Periodo 
	From dbDataDwItau.itau.Discador360 With(nolock)
	Where
		Data >= @Data30Dias
	Union
	Select
		IdDevedor, 
		IdTitulo, 
		'02. 60 Dias' as Periodo 
	From dbDataDwItau.itau.Discador360 With(nolock)
	Where
		Data >= @Data60Dias
	Union
	Select
		IdDevedor, 
		IdTitulo, 
		'03. 90 Dias' as Periodo 
	From dbDataDwItau.itau.Discador360 With(nolock)
	Where
		Data >= @Data90Dias
),

CRMAgregado as (
	Select 
		IdDevedor, 
		IdTitulo, 
		'01. 30 Dias' as Periodo, 
		1 as Atendimento, 
		Max(CPC) as CPC, 
		Max(Acordo) as Acordo,
		Max(Case when Referencia <> '000000' then Acordo end) as AcordoDireto,
		Max(Case when Referencia = '000000' then Acordo end) as AcordoIndireto
	From dbDataDwItau.itau.CRM360 With(nolock) 
	Where
		Data >= @Data30Dias 
	Group by
		IdDevedor, 
		IdTitulo
	
	Union all
	
	Select 
		IdDevedor, 
		IdTitulo, 
		'02. 60 Dias' as Periodo, 
		1 AS Atendimento, 
		Max(CPC) AS CPC, 
		Max(Acordo) as Acordo,
		Max(Case when Referencia <> '000000' then Acordo end) as AcordoDireto,
		Max(Case when Referencia = '000000' then Acordo end) as AcordoIndireto
	From dbDataDwItau.itau.CRM360 With(nolock)
	Where
		Data >= @Data60Dias 
	Group by
		IdDevedor, 
		IdTitulo
	
	Union all
	
	Select 
		IdDevedor, 
		IdTitulo, 
		'03. 90 Dias' as Periodo, 
		1 AS Atendimento, 
		Max(CPC) as CPC, 
		Max(Acordo) as Acordo,
		Max(Case when Referencia <> '000000' then Acordo end) as AcordoDireto,
		Max(Case when Referencia = '000000' then Acordo end) as AcordoIndireto
	From dbDataDwItau.itau.CRM360 With(nolock) 
	Where
		Data >= @Data90Dias 
	Group by
		IdDevedor, 
		IdTitulo
)

Insert into #BaseAtiva (
	Periodo, 
	IdBase, 
	IdDevedor, 
	IdTitulo, 
	CodigoReferencia, 
	Carteira, 
	Produto, 
    SubProduto, 
	Cluster,
	Categoria,
	DataInclusao, 
	FaixaAtraso, 
	SaldoVencido, 
	ValorRegularizacao, 
    FaixaValor, 
	Mailing, 
	Trabalhado, 
	Atendimento, 
	CPC, 
	Acordo,
	AcordoDireto,
	AcordoIndireto
)
Select
	P.Periodo,
	a.IdBase,
	a.IdDevedor,
	a.IdTitulo,
	a.CodigoReferencia,
	a.Carteira,
	a.Produto,
	a.SubProduto,
	a.Cluster,
	a.Categoria,
	a.DataInclusao,
	a.FaixaAtraso,
	a.SaldoVencido,
	a.ValorRegularizacao,
	a.FaixaValor,
	a.Mailing,
	Case when b.IdDevedor is not null or c.IdDevedor is not null then 1 end,
	c.Atendimento,
	c.CPC,
	c.Acordo,
	c.AcordoDireto,
	c.AcordoIndireto
From BasePrincipal a
Cross Apply (
    Values 
		('01. 30 Dias'), 
		('02. 60 Dias'), 
		('03. 90 Dias')
) P(Periodo)
Left join DiscadorAgregado b on a.IdDevedor = b.IdDevedor 
								and a.IdTitulo = b.IdTitulo 
								and p.Periodo = b.Periodo
Left join CRMAgregado c on a.IdDevedor = c.IdDevedor 
						   and a.IdTitulo = c.IdTitulo 
						   and p.Periodo = c.Periodo;

Create clustered index IxBaseAtiva on #BaseAtiva (Periodo, IdDevedor, CodigoReferencia);

--- | Base unificada

Insert into #BaseUnificada
Select
	Periodo,
	IdDevedor,
	CodigoReferencia,
	Carteira,
	Produto,
	SubProduto,
	Cluster,
	Categoria,
	Max(DataInclusao),
	Max(FaixaAtraso),
	Sum(SaldoVencido),
	Sum(ValorRegularizacao),
	Max(FaixaValor),
	Mailing,
	Max(Trabalhado),
	Max(Atendimento),
	Max(CPC),
	Max(Acordo),
	Max(AcordoDireto) as AcordoDireto,
	Max(AcordoIndireto) as AcordoIndireto
From #BaseAtiva
Group by
	Periodo,
	IdDevedor,
	CodigoReferencia,
	Carteira,
	Produto,
	SubProduto,
	Cluster,
	Categoria,
	Mailing;

------------------------------> Persistencia final

Set @Etapa = 'Persistencia final';

Truncate table dbDataDwItau.itau.Estratificacao360 
Insert into dbDataDwItau.itau.Estratificacao360 (
												Periodo,
												CodigoReferencia,
												Carteira,
												Produto,
												SubProduto,
												Cluster,
												Categoria,
												FaixaAtraso,
												FaixaValor,
												Base,
												ValorRegularizacao,
												ValorSaldoVencido,
												Entradas,
												BaseMailing,
												Trabalhado,
												Atendimento,
												CPC,
												Acordo,
												AcordoDireto,
												AcordoIndireto
											)
Select
	Periodo,
	CodigoReferencia,
	Carteira,
	Produto,
	SubProduto,
	Cluster,
	Categoria,
	FaixaAtraso,
	FaixaValor,
	Count(IdDevedor) as Base,
	Sum(ValorRegularizacao) as ValorRegularizacao,
	Sum(SaldoVencido) as SaldoVencido,
	Count(Case when DataInclusao >= Convert(date,Getdate()) then IdDevedor end) as Entradas,
	Sum(Mailing) as BaseMailing,
	Sum(Trabalhado) as Trabalhado,
	Sum(Atendimento) as Atendimento,
	Sum(CPC) as CPC,
	Sum(Acordo) as Acordo,
	Sum(AcordoDireto) as AcordoDireto,
	Sum(AcordoIndireto) as AcordoIndireto
From #BaseUnificada
Group by
	Periodo,
	CodigoReferencia,
	Carteira,
	Produto,
	SubProduto,
	Cluster,
	Categoria,
	FaixaAtraso,
	FaixaValor;

Set @LinhasInseridas = @@RowCount;
Set @DataHoraFim = Getdate();

/* Grava volumetria controles de log */
Exec dbDataDwItau.[log].ProcControles
    @TipoLog = 'Volumetria',
    @IdExecucao = @IdExecucao,
    @NomeTabelaDestino = 'itau.Estratificacao360',
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