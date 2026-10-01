Create or Alter Procedure itau.ProcResumoOperacional360 as 

------------------------------> Descrição da procedure

/*
    Padrão de escrita: PascalCase
    Nome: ProcResumoOperacional360
    DataCriação: 01/10/2026
    Criado por: Leonardo Matheus Talarico
    DataAtualização: 
    Atualizado por:

    Descrição atualização: (Data, Atualizado por, Descrição, git)
*/

------------------------------> Definições de variaveis e controles de ambiente

Set Nocount On;

Declare @NomeProcedure varchar(128) = 'ProcResumoOperacional360',
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

If Object_id('Tempdb..#ResumoOperacional') Is not null Drop table #ResumoOperacional;
Create table #ResumoOperacional (
	Data date,
	Hora time,
	CodigoReferencia smallint,
	Carteira varchar(64),
	Produto	varchar(64),
	SubProduto varchar(64),
	Cluster varchar(4),
	FaixaAtraso	varchar(32),
	ValorRegularizacao money,
	FaixaValor varchar(32),
	Referencia varchar(64),
	Nome varchar(128),
	Atendimento int,
	CPC int,
	Acordo int,
	ValorAcordo money
);

------------------------------> Carga das tabelas temporarias

Set @Etapa = 'Carga das tabelas temporarias';

--- | Insere novos acordos na tabela de origem

With AcordosCTE as (

	Select distinct
		IdBase,
		IdAcordo,
		DataCancelamento
	From dbDataDwItau.itau.Acordos360 With(nolock)
),

CRMCTE as (

	Select
		a.IdBase,
		Data,
		Cast(Dateadd(hour, Datediff(hour, 0, Data), 0) as time) as Hora,
		TipoOcorrencia,
		a.Referencia,
		c.Nome,
		Atendimento,
		CPC,
		Case when Convert(date,b.DataCancelamento) = Convert(date,a.Data) then null else Acordo end as Acordo
	From dbDataDwItau.itau.CRM360 a With(nolock)
	Left join AcordosCTE b With(nolock) on a.IdBase = b.IdBase
										   and a.IdAcordo = b.IdAcordo
	Left join misitau.misitau.dbo.Usuarios c With(nolock) on a.Referencia = c.Referencia
	Where
		a.Referencia <> '000000'

),
ResumoOperacional as (
	Select
		Convert(date,a.Data) as Data,
		a.Hora,
		b.CodigoReferencia,
		b.Carteira,
		b.Produto,
		b.SubProduto,
		b.Cluster,
		Max(b.FaixaAtraso) as FaixaAtraso,
		Sum(b.ValorRegularizacao) as ValorRegularizacao,
		Max(b.FaixaValor) as FaixaValor,
		a.Referencia,
		a.Nome,
		Sum(a.Atendimento) as Atendimento,
		Sum(a.CPC) as CPC,
		Sum(a.Acordo) as Acordo,
		Sum(Case when a.Acordo > 0 then b.ValorRegularizacao end) as ValorAcordo
	From CRMCTE a
	Inner join dbDataDwItau.itau.Base360 b With(nolock) on a.IdBase = b.IdBase
	Group by
		Convert(date,a.Data),
		a.Hora,
		b.CodigoReferencia,
		b.Carteira,
		b.Produto,
		b.SubProduto,
		b.Cluster,
		a.Referencia,
		a.Nome
)
Insert into #ResumoOperacional (
								Data,
								Hora,
								CodigoReferencia,
								Carteira,
								Produto,
								SubProduto,
								Cluster,
								FaixaAtraso,
								ValorRegularizacao,
								FaixaValor,
								Referencia,
								Nome,
								Atendimento,
								CPC,
								Acordo,
								ValorAcordo
								)
Select 
	Data,
	Hora,
	CodigoReferencia,
	Carteira,
	Produto,
	SubProduto,
	Cluster,
	FaixaAtraso,
	ValorRegularizacao,
	FaixaValor,
	Referencia,
	Nome,
	Atendimento,
	CPC,
	Acordo,
	ValorAcordo
From ResumoOperacional
Order by 
	1;

Set @LinhasOrigem = @@RowCount;

------------------------------> Persistencia final

Set @Etapa = 'Persistencia final';

--- | Delete na tabela fisica

Delete dbDataDwItau.itau.ResumoOperacional360;

--- | Tabela fisica

Insert into dbDataDwItau.itau.ResumoOperacional360(
												   Data,
												   Hora,
												   CodigoReferencia,
												   Carteira,
												   Produto,
												   SubProduto,
												   Cluster,
												   FaixaAtraso,
												   ValorRegularizacao,
												   FaixaValor,
												   Referencia,
												   Nome,
												   Atendimento,
												   CPC,
												   Acordo,
												   ValorAcordo
												  )
Select distinct
    Data,
	Hora,
	CodigoReferencia,
	Carteira,
	Produto,
	SubProduto,
	Cluster,
	FaixaAtraso,
	ValorRegularizacao,
	FaixaValor,
	Referencia,
	Nome,
	Atendimento,
	CPC,
	Acordo,
	ValorAcordo
From #ResumoOperacional a With(nolock);

Set @LinhasInseridas = @@RowCount;
Set @LinhasTotaisDestino = @LinhasInseridas + isnull(@LinhasAtualizadas, 0);
Set @DataHoraFim = Getdate();

/* Grava volumetria controles de log */
Exec dbDataDwItau.[log].ProcControles
    @TipoLog = 'Volumetria',
    @IdExecucao = @IdExecucao,
    @NomeTabelaDestino = 'itau.ResumoOperacional360',
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
Set @LinhaErro = Error_line()


/* Finalizacao execução de log erro */
Set @DataHoraFim = Dateadd(hour,-3,Getdate());
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