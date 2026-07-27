Create or Alter procedure dbo.ProcAcordosInformacoesComplementares as

------------------------------> Descrição da procedure

/*
	Padrão de escrita: PascalCase
	Nome: ProcAcordosInformacoesComplementares
	DataCriação: 27/07/2026
	Criado por: João Henrique Cavalheiro Grillo
	DataAtualização:
	Atualizado por:

	Descrição atualização: (Data, Atualizado por, Descrição, git)
*/

------------------------------> Definições de variaveis e controles de ambiente

Set Nocount On;

Declare @NomeProcedure varchar(128) = 'ProcAcordosInformacoesComplementares',
        @Etapa varchar(100) = 'Inicio',
		@IdAcordo varchar(max),
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
	JsonResumo varchar(max),
	CondicoesGeraisBase64 varchar(max),
	CodigoAlcada smallint,
	CodigoBanco varchar(4),
	NumeroAgencia varchar(5),
	NumeroConta varchar(20)
);

------------------------------> Carga das tabelas temporarias

Set @Etapa = 'Carga das tabelas temporarias';

--- | Insere novos acordos na tabela

Set @IdAcordo = (Select 
					String_agg(Convert(varchar(max),IdAcordo),',') 
				From misitau.dbo.Acordos a With(nolock)
				Where
					Not exists (Select 1
								From misitau.dbo.AcordosInformacoesComplementares b With(nolock)
								Where
									a.IdAcordo = b.IdAcordo));

Set @SQLAcordosInformacoesComplementares = N'
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
												JsonResumo,
												CondicoesGeraisBase64,
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
	JsonResumo,
	CondicoesGeraisBase64,
	CodigoAlcada,
	CodigoBanco,
	NumeroAgencia,
	NumeroConta
From misitau.cli.AcordosInformacoesComplementares a
Where
	IdAcordo in (' + @IdAcordo + ')';

Exec sp_executesql @SQLAcordosInformacoesComplementares;

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
														JsonResumo,
														CondicoesGeraisBase64,
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
	JsonResumo,
	CondicoesGeraisBase64,
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