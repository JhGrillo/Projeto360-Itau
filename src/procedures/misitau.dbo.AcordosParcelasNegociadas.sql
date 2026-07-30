Create or Alter Table dbo.ProcAcordosParcelasNegociadas as

------------------------------> Descrição da procedure

/*
	Padrão de escrita: PascalCase
	Nome: ProcAcordosParcelasNegociadas
	DataCriação: 27/07/2026
	Criado por: Leonardo Matheus Talarico
	DataAtualização:
	Atualizado por: Leonardo Matheus Talarico

	Descrição atualização: (Data, Atualizado por, Descrição, git)

	30/07/2026 Leonardo Matheus Talarico: Foi alterado a forma que captura os dados, baseando-se agora na data de penúltima execução da dbo.Acordos para seguir a mesma regra
	consultando diretamente na origem, agora a procedure é mais escalavel.
*/

------------------------------> Definições de variaveis e controles de ambiente

Set Nocount On;

Declare @NomeProcedure varchar(128) = 'ProcAcordosParcelasNegociadas',
        @Etapa varchar(100) = 'Inicio',
		@UltimaAtualizacao datetime,
		@DataPagamento datetime,
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

--- | Origem

If Object_id('Tempdb..#DadosOrigem') Is not null Drop table #DadosOrigem;
Create table #DadosOrigem (
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
	DescricaoParcelas varchar(500),
	PercentualDescontoAutorizado float
);

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
	DescricaoParcelas varchar(32),
	PercentualDescontoAutorizado float
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

	union all

	Select
		IdAcordo
	From misitau.cob.AcordosParcelasPagar b
	Where
		b.DataPagamento = @DataPagamento
		or b.DataVencimento between @UltimaAtualizacao and Convert(date,Dateadd(hour,-3,Getdate()))
) 

Insert into #DadosOrigem (
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
From misitau.cob.AcordosParcelasNegociadas a
Where
	Exists (Select 1
			From AcordosCTE b
			Where
				a.IdAcordo = b.IdAcordo);

/* Cria index clusterizado 
Obs: Este index é criado fora da etapa de index devido a necessidade de performance no comparativo abaixo.
*/
Create nonclustered Index IxAcordosParcelasNegociadas on #DadosOrigem (IdAcordo);

--- | Acordos Parcelas Negociadas

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
From #DadosOrigem a
Where
	Not exists (Select 1
				From misitau.dbo.AcordosParcelasNegociadas b With(nolock)
				Where
					a.IdAcordo = b.IdAcordo);

Set @LinhasOrigem = @@RowCount;

------------------------------> Criacao de índices

Set @Etapa = 'Criacao de indices';

/* Cria index não clusterizado */
Create nonclustered index IxAcordosParcelasNegociadas on #AcordosParcelasNegociadas (IdAcordo);

------------------------------> Persistencia final

--- | Tabela fisica

Insert into misitau.dbo.AcordosParcelasNegociadas (
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
				From misitau.dbo.AcordosParcelasNegociadas b With(nolock)
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
