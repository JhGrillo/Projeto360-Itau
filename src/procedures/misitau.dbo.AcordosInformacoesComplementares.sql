Create or Alter procedure dbo.ProcAcordosInformacoesComplementares as

------------------------------> Descrição da procedure

/*
	Padrão de escrita: PascalCase
	Nome: ProcAcordosInformacoesComplementares
	DataCriação: 27/07/2026
	Criado por: João Henrique Cavalheiro Grillo
	DataAtualização: 30/07/2026
	Atualizado por: João Henrique Cavalheiro Grillo

	Descrição atualização: (Data, Atualizado por, Descrição, git)

	30/07/2026 João Henrique Cavalheiro Grillo: Foi alterado a forma que captura dados, agora se baseia nas datas da penultima execução da dbo.Acordo para seguir a mesma regra
	consultando diretamente na origem, agora a procedure é mais escalave.
*/

------------------------------> Definições de variaveis e controles de ambiente

Set Nocount On;

Declare @NomeProcedure varchar(128) = 'ProcAcordosInformacoesComplementares',
        @Etapa varchar(100) = 'Inicio',
		@UltimaAtualizacao datetime,
		@DataPagamento datetime,
		@SQLAcordosInformacoesComplementares nvarchar(max),
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
	IdAcordo int,
	DataEnvioProposta smalldatetime,
	ValorContraProposta money,
	PlanoContraProposta tinyint,
	DataVencimentoContraProposta date,
	DataRetorno smalldatetime,
	IdCampanhaCodigoBarra bigint,
	IdBoleto int,
	IdJornada varchar(24),
	IdSimulacao varchar(24),
	IdCondicaoGeral varchar(24),
	IdResumo varchar(24),
	CodigoAlcada smallint,
	CodigoBanco varchar(4),
	NumeroAgencia varchar(5),
	NumeroConta varchar(20)
);

--- | Acordos informações complementares

If Object_id('Tempdb..#AcordosInformacoesComplementares') Is not null Drop table #AcordosInformacoesComplementares;
Create table #AcordosInformacoesComplementares (
	IdAcordo int,
	DataEnvioProposta smalldatetime,
	ValorContraProposta money,
	PlanoContraProposta tinyint,
	DataVencimentoContraProposta date,
	DataRetorno smalldatetime,
	IdCampanhaCodigoBarra bigint,
	IdBoleto int,
	IdJornada varchar(24),
	IdSimulacao varchar(24),
	IdCondicaoGeral varchar(24),
	IdResumo varchar(24),
	CodigoAlcada smallint,
	CodigoBanco varchar(4),
	NumeroAgencia varchar(5),
	NumeroConta varchar(20)
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
					IdAcordo,
					DataEnvioProposta,
					ValorContraProposta,
					PlanoContraProposta,
					DataVencimentoContraProposta,
					DataRetorno,
					IdCampanhaCodigoBarra,
					IdBoleto,
					IdJornada,
					IdSimulacao,
					IdCondicaoGeral,
					IdResumo,
					CodigoAlcada,
					CodigoBanco,
					NumeroAgencia,
					NumeroConta
				)
Select
	IdAcordo,
	DataEnvioProposta,
	ValorContraProposta,
	PlanoContraProposta,
	DataVencimentoContraProposta,
	DataRetorno,
	IdCampanhaCodigoBarra,
	IdBoleto,
	IdJornada,
	IdSimulacao,
	IdCondicaoGeral,
	IdResumo,
	CodigoAlcada,
	CodigoBanco,
	NumeroAgencia,
	NumeroConta
From misitau.cli.AcordosInformacoesComplementares a
Where
	Exists (Select 1
			From AcordosCTE b
			Where
				a.IdAcordo = b.IdAcordo);

/* Cria index clusterizado 
Obs: Este index é criado fora da etapa de index devido a necessidade de performance no comparativo abaixo.
*/
Create nonclustered Index IxAcordosInformacoesComplementares on #DadosOrigem (IdAcordo);

--- | Acordos Informacoes Complementares

Insert into #AcordosInformacoesComplementares (
												IdAcordo,
												DataEnvioProposta,
												ValorContraProposta,
												PlanoContraProposta,
												DataVencimentoContraProposta,
												DataRetorno,
												IdCampanhaCodigoBarra,
												IdBoleto,
												IdJornada,
												IdSimulacao,
												IdCondicaoGeral,
												IdResumo,
												CodigoAlcada,
												CodigoBanco,
												NumeroAgencia,
												NumeroConta
											)
Select
	IdAcordo,
	DataEnvioProposta,
	ValorContraProposta,
	PlanoContraProposta,
	DataVencimentoContraProposta,
	DataRetorno,
	IdCampanhaCodigoBarra,
	IdBoleto,
	IdJornada,
	IdSimulacao,
	IdCondicaoGeral,
	IdResumo,
	CodigoAlcada,
	CodigoBanco,
	NumeroAgencia,
	NumeroConta
From #DadosOrigem a
Where
	Not exists (Select 1
				From misitau.dbo.AcordosInformacoesComplementares b With(nolock)
				Where
					a.IdAcordo = b.IdAcordo);
	
Set @LinhasOrigem = @@RowCount;

------------------------------> Criacao de índices

Set @Etapa = 'Criacao de indices';

/* Cria index não clusterizado */
Create nonclustered index IxAcordosInformacoesComplementares on #AcordosInformacoesComplementares (IdAcordo);

------------------------------> Persistencia final

Set @Etapa = 'Persistencia final';

--- | Tabela fisica

Insert into misitau.dbo.AcordosInformacoesComplementares (
														IdAcordo,
														DataEnvioProposta,
														ValorContraProposta,
														PlanoContraProposta,
														DataVencimentoContraProposta,
														DataRetorno,
														IdCampanhaCodigoBarra,
														IdBoleto,
														IdJornada,
														IdSimulacao,
														IdCondicaoGeral,
														IdResumo,
														CodigoAlcada,
														CodigoBanco,
														NumeroAgencia,
														NumeroConta
														)
Select distinct
	IdAcordo,
	DataEnvioProposta,
	ValorContraProposta,
	PlanoContraProposta,
	DataVencimentoContraProposta,
	DataRetorno,
	IdCampanhaCodigoBarra,
	IdBoleto,
	IdJornada,
	IdSimulacao,
	IdCondicaoGeral,
	IdResumo,
	CodigoAlcada,
	CodigoBanco,
	NumeroAgencia,
	NumeroConta
From #AcordosInformacoesComplementares a With(nolock)
Where
	Not exists (Select 1
				From misitau.dbo.AcordosInformacoesComplementares b With(nolock)
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