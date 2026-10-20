Create or Alter Procedure itau.ProcQuartilDia360 as 

------------------------------> Descrição da procedure

/*
    Padrão de escrita: PascalCase
    Nome: ProcBase360
    DataCriação: 20/10/2026
    Criado por: Leonardo Matheus Talarico
    DataAtualização:
    Atualizado por: 

    Descrição atualização: (Data, Atualizado por, Descrição, git)

*/

------------------------------> Definições de variaveis e controles de ambiente

set Nocount on;

Declare @NomeProcedure varchar(128) = 'ProcQuartilDia360',
        @Etapa varchar(100) = 'Inicio',
        @IdExecucao int,
		@MediaUltimasExecucoes int,
        @MediaVolumetria int,
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

------------------------------> Limpeza de tabela

Set @Etapa = 'Limpeza de tabela';

--- | Limpeza da tabela pelo periodo de analitico disponivel

Set @DataIni = Dateadd(month, Datediff(month, 0, Getdate()),0);
Set @DataFim = Dateadd(day, Datediff(day, 0, Getdate()),0) + '23:59';

Delete 
from dbDataDwItau.itau.QuartilDia360
Where
	Data between @DataIni and @DataFim;

------------------------------> Criacao de tabelas temporarias

Set @Etapa = 'Criação das tabelas temporarias';

--- | Quartil Dia 360

If Object_id('Tempdb..#QuartilDia360') Is not null Drop table #QuartilDia360;
Create Table #QuartilDia360 (
	Data datetime,
	CodigoReferencia int,
	Carteira varchar(64),
	DiaUtil int,
	SubProduto varchar(64),
	Cluster varchar(32),
	Referencia varchar(64),
	Nome varchar(150),
	Coordenador varchar(64),
	Supervisor varchar(64),
	ValorCaixa money,
	ValorRegularizacao money,
	MetaCaixa money,
	MetaRegularizacao money,
	ICMCaixa float,
	ICMRegularizacao float,
	ValorCaixaProjetado money,
	ValorRegularizacaoProjetado money,
	IcmProjetadoCaixa float,
	IcmProjetadoRegularizacao float
);

------------------------------> Carga de tabelas temporarias

Set @Etapa = 'Carga das tabelas temporarias';

--- | Quartil Dia 360

/* Calendario */

With CalendarioCTE as (
Select 
	Data,
	Mes,
	Ano,
	DiaUtil,
	Feriado
From
	[srv-dbbi].Dw.geral.Calendario With(nolock)
Where
	Year(Data) = Year(@DataIni)
	and Month(Data) = Month(@DataIni)
),

/* Agregação de Pagamentos */
PagamentosCTE as(
	Select distinct
		IdBase,
		Data as DataPagamento,
		ValorPago,
		Referencia
	From dbDataDwItau.itau.Pagamentos360 With(nolock)
	Where
		Data Between @DataIni and @DataFim
),

/* Agregação de Base */
BaseCTE as (
	Select distinct
		IdBase,
		Data,
		CodigoReferencia,
		Carteira,
		SubProduto,
		Case When Cluster like 'W%' then 'WO' else 'Ativo' end as Cluster,
		ValorRegularizacao
	From dbDataDwItau.itau.Base360 With(nolock)
	Where 
		Data Between @DataIni and @DataFim
),

/* Agregação de Capacity */
CapacityCTE as (
	Select distinct
		CD_USR as Referencia,
		Max(Convert(int, Right(Ref, 2))) as Mes,
		dbDataDwItau.dbo.fnFormatarTexto(Coringa_2) as Equipe,
		Case When Coringa_3 like 'PURC%' Then 'Purc' Else Coringa_3 End as Carteira,
		Case When Coringa_3 like 'PURC%' Then Replace(Coringa_3, 'Purc', '') Else Coringa_3 End as SubProduto,
		dbDataDwItau.dbo.fnFormatarTexto(Nm_fun) as Nome,
		NM_CRD as Coordenador,
		NM_SPV as Supervisor
	From [srv-dbbi].[dbdatadwitau].[itau].[ControleCapacityHistorico] a With(nolock)
	Where
		Dc_Sit not in ('Desligado')
	Group by
		dbDataDwItau.dbo.fnFormatarTexto(Coringa_2),
		Coringa_3,
		CD_USR,
		Nm_fun,
		NM_CRD,
		NM_SPV
),

/* Agregação de Usuarios */
UsuariosCTE as (
	Select Distinct
		Max(a.Mes) as Mes,
		b.Referencia,
		dbDataDwItau.dbo.fnFormatarTexto(b.Nome) as Nome,
		Case When Equipe like 'WO%' then 'WO' else Equipe end as Equipe,
		a.Carteira,
		a.Subproduto,
		a.Coordenador,
		a.Supervisor
	From CapacityCTE a With(nolock)
	Inner join misitau.misitau.dbo.Usuarios b With(nolock) on a.Referencia = b.Referencia							
	Where
		Mes >= (Select Max(Mes) From CapacityCTE)
	Group by
		b.Referencia,
		b.Nome,
		a.Equipe,
		a.Carteira,
		a.Subproduto,
		a.Coordenador,
		a.Supervisor
),

/* Agregação de Metas */
MetasCTE as (
	Select
		Mes,
		dbDataDwItau.dbo.fnFormatarTexto(Equipe) as Equipe,
		SubProduto,
		MetaCaixa,
		MetaRegularizacao,
		Segmento
	From (
		Select
			Convert(int, Right(Ref, 2)) as Mes,
			Equipe,
			Case when Carteira like 'Purc%' then Replace(Carteira, 'Purc', '') else Carteira end as SubProduto,
			Case When Tipo = 'MetaCaixa' then Meta_1 End as MetaCaixa,
			Case When Tipo = 'MetaRegularização' then Meta_1 End as MetaRegularizacao,
			Segmento
		From
			[srv-dbbi].[dbDataDwItau].[Itau].[MetasQuartil] With(nolock)
	
		Union all 

		Select
			Convert(int, Right(Ref, 2)) as Mes,
			Equipe,
			Case when Carteira like 'Purc%' then Replace(Carteira, 'Purc', '') else Carteira end as SubProduto,
			Case When Tipo = 'MetaCaixa' then Meta_1 End as MetaCaixa,
			Case When Tipo = 'MetaRegularização' then Meta_1 End as MetaRegularizacao,
			Segmento
		From
			dbDataDwItau.Itau.MetasQuartil With(nolock)
	) a
),

/* Agregação de Metas por usuarios */
ConsolidaMetasCTE as (
	Select Distinct
		a.Referencia,
		a.Nome,
		a.Equipe,
		a.Carteira,
		a.SubProduto,
		a.Coordenador,
		a.Supervisor,
		b.MetaCaixa,
		b.MetaRegularizacao	
	From UsuariosCTE a
	inner join (Select Distinct
					Mes,
					dbDataDwItau.dbo.fnFormatarTexto(Equipe) as Equipe,
					SubProduto,
					Case when Segmento = 'Hibrida' or (Segmento = 'Geral' and Equipe like 'wo%') then Sum(MetaCaixa) End as MetaCaixa,
					Case when Segmento = 'Hibrida' then Sum(MetaRegularizacao) end as MetaRegularizacao
				From
					MetasCTE
				Where 
					Mes >= (Select Max(Mes) From MetasCTE)
				Group by
					Mes,
					Equipe,
					SubProduto,
					Segmento) b on a.Equipe = b.Equipe
								and a.SubProduto = b.Subproduto
	Where
		b.Mes = (Select Max(Mes) From MetasCTE)
),

/* Agregação de Meta e Pagamentos */
MetaPagamentosCTE as (
	Select Distinct
		a.DataPagamento as Data,
		b.CodigoReferencia,
		b.Carteira, 
		b.SubProduto,
		b.Cluster,
		c.Referencia,
		c.Nome,
		c.Coordenador,
		c.Supervisor,
		Sum(a.ValorPago) as ValorCaixa,
		Sum(b.ValorRegularizacao) as ValorRegularizacao,
		c.MetaCaixa,
		Case When b.Cluster = 'WO' then '' else c.MetaRegularizacao end as MetaRegularizacao
	From PagamentosCTE a
	Left join BaseCTE b on a.IdBase = b.IdBase
	Left join ConsolidaMetasCTE c on a.Referencia = c.Referencia
	Group by
		a.DataPagamento,
		b.CodigoReferencia,
		b.Carteira, 
		b.SubProduto,
		b.Cluster,
		c.Referencia,
		c.Nome,
		c.Coordenador,
		c.Supervisor,
		c.MetaCaixa,
		c.MetaRegularizacao
),
/* Grava o maximo de dias uteis do mes */
DiasUteisMes as (
	Select 
		Mes, 
		Max(DiaUtil) as DiaUtil 
	From CalendarioCTE 
	Group by 
		Mes
),

/* Calculo de Icm */
IcmCTE as (
	Select 
		a.Data,
		CodigoReferencia,
		Carteira,
		b.DiaUtil,
		c.DiaUtil as DiasUteisMes,
		SubProduto,
		Cluster,
		Referencia,
		Nome,
		Coordenador,
		Supervisor,
		ValorCaixa,
		ValorRegularizacao,
		Nullif(MetaCaixa, 0) as MetaCaixa,
		Nullif(MetaRegularizacao, 0) as MetaRegularizacao,
		ValorCaixa / NULLIF(MetaCaixa, 0) as ICMCaixa,
		Nullif(ValorRegularizacao / NULLIF(MetaRegularizacao, 0), 0) as ICMRegularizacao
	From MetaPagamentosCTE a
	inner join CalendarioCTE b on a.Data = b.Data
	inner join DiasUteisMes c on Month(a.Data) = c.Mes
)

--- | Quartil Dia 360
Insert into #QuartilDia360 (
							Data,
							CodigoReferencia,
							Carteira,
							DiaUtil,
							SubProduto,
							Cluster,
							Referencia,
							Nome,
							Coordenador,
							Supervisor,
							ValorCaixa,
							ValorRegularizacao,
							MetaCaixa,
							MetaRegularizacao,
							ICMCaixa,
							ICMRegularizacao,
							ValorCaixaProjetado,
							ValorRegularizacaoProjetado,
							IcmProjetadoCaixa,
							IcmProjetadoRegularizacao
							)
Select Distinct
	Data,
	CodigoReferencia,
	Carteira,
	DiaUtil,
	SubProduto,
	Cluster,
	Referencia,
	Nome,
	Coordenador,
	Supervisor,
	ValorCaixa,
	ValorRegularizacao,
	MetaCaixa,
	MetaRegularizacao,
	ICMCaixa,
	ICMRegularizacao,
	((ValorCaixa / DiaUtil) *  DiasUteisMes) as ValorCaixaProjetado,
	Case When Cluster = 'WO' then cast(null as money) else ((ValorRegularizacao / DiaUtil) * DiasUteisMes) end as ValorRegularizacaoProjetado,
	((ValorCaixa / DiaUtil) * DiasUteisMes) / MetaCaixa as IcmProjetadoCaixa,
	((ValorRegularizacao / DiaUtil) * DiasUteisMes) / MetaRegularizacao as IcmProjetadoRegularizacao
From IcmCTE
Where
	Nome is not null;

Set @LinhasOrigem = @@RowCount;

------------------------------> Persistencia final

Set @Etapa = 'Persistencia final';

--- | Tabela fisica

Insert into dbDataDwItau.itau.QuartilDia360 (
											 Data,
											 CodigoReferencia,
											 Carteira,
											 DiaUtil,
											 SubProduto,
											 Cluster,
											 Referencia,
											 Nome,
											 Coordenador,
											 Supervisor,
											 ValorCaixa,
											 ValorRegularizacao,
											 MetaCaixa,
											 MetaRegularizacao,
											 ICMCaixa,
											 ICMRegularizacao,
											 ValorCaixaProjetado,
											 ValorRegularizacaoProjetado,
											 IcmProjetadoCaixa,
											 IcmProjetadoRegularizacao
											 )
Select
	Data,
	CodigoReferencia,
	Carteira,
	DiaUtil,
	SubProduto,
	Cluster,
	Referencia,
	Nome,
	Coordenador,
	Supervisor,
	ValorCaixa,
	ValorRegularizacao,
	MetaCaixa,
	MetaRegularizacao,
	ICMCaixa,
	ICMRegularizacao,
	ValorCaixaProjetado,
	ValorRegularizacaoProjetado,
	IcmProjetadoCaixa,
	IcmProjetadoRegularizacao
From
	#QuartilDia360;

Set @LinhasInseridas = @@Rowcount;
Set @LinhasTotaisDestino = @LinhasInseridas;
Set @DataHoraFim = Getdate();

/* Grava volumetria controles de log */
Exec dbDataDwItau.[log].ProcControles
    @TipoLog = 'Volumetria',
    @IdExecucao = @IdExecucao,
    @NomeTabelaDestino = 'itau.QuartilDia360',
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