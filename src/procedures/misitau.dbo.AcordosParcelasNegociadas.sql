Create or Alter Procedure dbo.ProcAcordosParcelasNegociadas as
------------------------------> Descrição da procedure

/*
	Padrão de escrita: PascalCase
	Nome: ProcAcordosParcelasNegociadas
	DataCriação: 27/07/2026
	Criado por: Leonardo Matheus Talarico
	DataAtualização:
	Atualizado por:

	Descrição atualização: (Data, Atualizado por, Descrição, git)
*/

------------------------------> Definições de variaveis e controles de ambiente

Set Nocount On;

Declare @NomeProcedure varchar(128) = 'ProcAcordosParcelasNegociadas',
        @Etapa varchar(100) = 'Inicio',
		@IdAcordo varchar(max),
		@SQLAcordosParcelasNegociadas nvarchar(max),
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

--- | Acordos parcelas negociadas

If Object_id('Tempdb..#AcordosParcelasNegociadas') Is not null Drop table #AcordosParcelasNegociadas;
Create table #AcordosParcelasNegociadas (
	IdAcordoParcelaNegociada int,
	IdAcordo int,
	IdTitulo int,
	IdParcela int,
	FaixaAtraso smallint,
	ValorPrincipalAtualizado money,
	ValorPrincipalCampanha money,
	ValorCobrado money,
	ValorJurosMoratoriosAtualizado money,
	ValorJurosMoratoriosCampanha money,
	ValorJurosMoratoriosCobrado	money,
	ValorJurosRemuneratoriosAtualizado money,
	ValorJurosRemuneratoriosCampanha money,
	ValorJurosRemuneratoriosCobrado money,
	ValorMultaAtualizado money,
	ValorMultaCampanha money,
	ValorMultaCobrado money,
	ValorHonorariosAtualizado money,
	ValorHonorariosCampanha money,
	ValorHonorariosCobrado money,
	ValorDespesaCobrado money,
	ValorDescontoCliente money,
	PercentualPrincipalCampanha float,
	PercentualPrincipalCobrado float,
	PercentualMultaPadrao float,
	PercentualMultaCampanha float,
	PercentualMultaCobrado float,
	PercentualJurosRemuneratoriosPadrao float,
	PercentualJurosRemuneratoriosCampanha float,
	PercentualJurosRemuneratoriosCobrado float,
	PercentualHonorariosPadrao float,
	PercentualHonorariosCampanha float,
	PercentualHonorariosCobrado float,
	PercentualJurosMoratoriosPadrao float,
	PercentualJurosMoratoriosCampanha float,
	PercentualJurosMoratoriosCobrado float,
	NumeroParcela smallint,
	ValorComissaoAssessoria money,
	DescricaoParcelas varchar,
	PercentualDescontoAutorizado float
);

------------------------------> Carga das tabelas temporarias

Set @Etapa = 'Carga das tabelas temporarias';

--- | Insere novos acordos na tabela

Set @IdAcordo = (Select 
					String_agg(Convert(varchar(max),IdAcordo),',') 
				From misitau.dbo.Acordos a With(nolock)
				Where
					Not exists (Select 1
								From misitau.dbo.AcordosParcelasNegociadas b With(nolock)
								Where
									a.IdAcordo = b.IdAcordo));

Set @SQLAcordosParcelasNegociadas = N'
Insert into #AcordosParcelasNegociadas (
										IdAcordoParcelaNegociada,
										IdAcordo,
										IdTitulo,
										IdParcela,
										FaixaAtraso,
										ValorPrincipalAtualizado,
										ValorPrincipalCampanha,
										ValorCobrado,
										ValorJurosMoratoriosAtualizado,
										ValorJurosMoratoriosCampanha,
										ValorJurosMoratoriosCobrado,
										ValorJurosRemuneratoriosAtualizado,
										ValorJurosRemuneratoriosCampanha,
										ValorJurosRemuneratoriosCobrado,
										ValorMultaAtualizado,
										ValorMultaCampanha,
										ValorMultaCobrado,
										ValorHonorariosAtualizado,
										ValorHonorariosCampanha,
										ValorHonorariosCobrado,
										ValorDespesaCobrado,
										ValorDescontoCliente,
										PercentualPrincipalCampanha,
										PercentualPrincipalCobrado,
										PercentualMultaPadrao,
										PercentualMultaCampanha,
										PercentualMultaCobrado,
										PercentualJurosRemuneratoriosPadrao,
										PercentualJurosRemuneratoriosCampanha,
										PercentualJurosRemuneratoriosCobrado,
										PercentualHonorariosPadrao,
										PercentualHonorariosCampanha,
										PercentualHonorariosCobrado,
										PercentualJurosMoratoriosPadrao,
										PercentualJurosMoratoriosCampanha,
										PercentualJurosMoratoriosCobrado,
										NumeroParcela,
										ValorComissaoAssessoria,
										DescricaoParcelas,
										PercentualDescontoAutorizado
										)
Select
	IdAcordoParcelaNegociada,
	IdAcordo,
	IdTitulo,
	IdParcela,
	FaixaAtraso,
	ValorPrincipalAtualizado,
	ValorPrincipalCampanha,
	ValorCobrado,
	ValorJurosMoratoriosAtualizado,
	ValorJurosMoratoriosCampanha,
	ValorJurosMoratoriosCobrado,
	ValorJurosRemuneratoriosAtualizado,
	ValorJurosRemuneratoriosCampanha,
	ValorJurosRemuneratoriosCobrado,
	ValorMultaAtualizado,
	ValorMultaCampanha,
	ValorMultaCobrado,
	ValorHonorariosAtualizado,
	ValorHonorariosCampanha,
	ValorHonorariosCobrado,
	ValorDespesaCobrado,
	ValorDescontoCliente,
	PercentualPrincipalCampanha,
	PercentualPrincipalCobrado,
	PercentualMultaPadrao,
	PercentualMultaCampanha,
	PercentualMultaCobrado,
	PercentualJurosRemuneratoriosPadrao,
	PercentualJurosRemuneratoriosCampanha,
	PercentualJurosRemuneratoriosCobrado,
	PercentualHonorariosPadrao,
	PercentualHonorariosCampanha,
	PercentualHonorariosCobrado,
	PercentualJurosMoratoriosPadrao,
	PercentualJurosMoratoriosCampanha,
	PercentualJurosMoratoriosCobrado,
	NumeroParcela,
	ValorComissaoAssessoria,
	DescricaoParcelas,
	PercentualDescontoAutorizado
From misitau.cob.AcordosParcelasNegociadas
Where
	IdAcordo in (' + @IdAcordo + ')';

Exec sp_executesql @SQLAcordosParcelasNegociadas;

Set @LinhasOrigem = @@RowCount;

------------------------------> Criacao de índices

Set @Etapa = 'Criacao de indices';

/* Cria index não clusterizado */
Create nonclustered index IxAcordosParcelasNegociadas on #AcordosParcelasNegociadas (IdAcordo);

------------------------------> Persistencia final

--- | Tabela fisica

Insert into dbo.AcordosParcelasNegociadas (
											IdAcordoParcelaNegociada,
											IdAcordo,
											IdTitulo,
											IdParcela,
											FaixaAtraso,
											ValorPrincipalAtualizado,
											ValorPrincipalCampanha,
											ValorCobrado,
											ValorJurosMoratoriosAtualizado,
											ValorJurosMoratoriosCampanha,
											ValorJurosMoratoriosCobrado,
											ValorJurosRemuneratoriosAtualizado,
											ValorJurosRemuneratoriosCampanha,
											ValorJurosRemuneratoriosCobrado,
											ValorMultaAtualizado,
											ValorMultaCampanha,
											ValorMultaCobrado,
											ValorHonorariosAtualizado,
											ValorHonorariosCampanha,
											ValorHonorariosCobrado,
											ValorDespesaCobrado,
											ValorDescontoCliente,
											PercentualPrincipalCampanha,
											PercentualPrincipalCobrado,
											PercentualMultaPadrao,
											PercentualMultaCampanha,
											PercentualMultaCobrado,
											PercentualJurosRemuneratoriosPadrao,
											PercentualJurosRemuneratoriosCampanha,
											PercentualJurosRemuneratoriosCobrado,
											PercentualHonorariosPadrao,
											PercentualHonorariosCampanha,
											PercentualHonorariosCobrado,
											PercentualJurosMoratoriosPadrao,
											PercentualJurosMoratoriosCampanha,
											PercentualJurosMoratoriosCobrado,
											NumeroParcela,
											ValorComissaoAssessoria,
											DescricaoParcelas,
											PercentualDescontoAutorizado
											)
Select distinct
	IdAcordoParcelaNegociada,
	IdAcordo,
	IdTitulo,
	IdParcela,
	FaixaAtraso,
	ValorPrincipalAtualizado,
	ValorPrincipalCampanha,
	ValorCobrado,
	ValorJurosMoratoriosAtualizado,
	ValorJurosMoratoriosCampanha,
	ValorJurosMoratoriosCobrado,
	ValorJurosRemuneratoriosAtualizado,
	ValorJurosRemuneratoriosCampanha,
	ValorJurosRemuneratoriosCobrado,
	ValorMultaAtualizado,
	ValorMultaCampanha,
	ValorMultaCobrado,
	ValorHonorariosAtualizado,
	ValorHonorariosCampanha,
	ValorHonorariosCobrado,
	ValorDespesaCobrado,
	ValorDescontoCliente,
	PercentualPrincipalCampanha,
	PercentualPrincipalCobrado,
	PercentualMultaPadrao,
	PercentualMultaCampanha,
	PercentualMultaCobrado,
	PercentualJurosRemuneratoriosPadrao,
	PercentualJurosRemuneratoriosCampanha,
	PercentualJurosRemuneratoriosCobrado,
	PercentualHonorariosPadrao,
	PercentualHonorariosCampanha,
	PercentualHonorariosCobrado,
	PercentualJurosMoratoriosPadrao,
	PercentualJurosMoratoriosCampanha,
	PercentualJurosMoratoriosCobrado,
	NumeroParcela,
	ValorComissaoAssessoria,
	DescricaoParcelas,
	PercentualDescontoAutorizado
From #AcordosParcelasNegociadas a With(nolock)
Where
	Not exists (Select 1
				From dbo.AcordosParcelasNegociadas b With(nolock)
				Where
					a.IdAcordo = b.IdAcordo);

Set @LinhasInseridas = @@RowCount;
Set @LinhasTotaisDestino = @LinhasInseridas;
Set @DataHoraFim = Dateadd(hour,-3,Getdate());

/* Grava volumetria controles de log */
Exec misitau.[log].ProcControles
    @TipoLog = 'Volumetria',
    @IdExecucao = @IdExecucao,
    @NomeTabelaOrigem = 'cli.AcordosInformacoesComplementares',
    @NomeTabelaDestino = 'dbo.AcordosInformacoesComplementares',
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
