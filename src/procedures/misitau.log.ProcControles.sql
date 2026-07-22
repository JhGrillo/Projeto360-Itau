Create or alter procedure log.[ProcControles]
	@TipoLog varchar(20),
	@NomeProcedure varchar(128) = null,
	@DataHoraInicio datetime = null,
	@DataHoraFim datetime = null,
	@StatusExecucao varchar(20) = null,
	@NomeTabelaOrigem varchar(128) = null,
	@NomeTabelaDestino varchar(128) = null,
	@LinhasOrigem int = null,
	@LinhasInseridas int = null,
	@LinhasAtualizadas int = null,
	@LinhasTotaisDestino int = null,
	@MensagemErro varchar(max) = null,
	@NumeroErro int = null,
	@LinhaErro int = null,
	@EtapaErro varchar(100) = null,
	@IdTabelaExpurgo int = null,
	@NomeTabela varchar(64) = null,
	@IdExecucao int = null OUTPUT
as

Begin

	Set nocount on;

	/* Captura execuções */
	If @TipoLog = 'Execucao'
	Begin

		Insert into [log].ControleExecucoes (NomeProcedure, DataHoraInicio, StatusExecucao)
		Values (
			@NomeProcedure,
			@DataHoraInicio,
			@StatusExecucao
		);

		Set @IdExecucao = Scope_identity();
	end

	/* Captura volumetria de tabelas */
	If @TipoLog = 'Volumetria'
	Begin
		Insert into [log].ControleVolumes (IdExecucao, NomeTabelaOrigem, NomeTabelaDestino, LinhasOrigem, LinhasInseridas, LinhasAtualizadas, LinhasTotaisDestino, DataExecucao)
		Values (
			@IdExecucao,
			@NomeTabelaOrigem,
			@NomeTabelaDestino,
			Isnull(@LinhasOrigem, 0),
			Isnull(@LinhasInseridas, 0),
			Isnull(@LinhasAtualizadas, 0),
			Isnull(@LinhasTotaisDestino, 0),
			Dateadd(hour,-3,Getdate())
		);
	end

	/* Captura erros de execuções */
	If @TipoLog = 'Erro'
	Begin
		Insert into [log].ControleErros (IdExecucao, NomeProcedure, DataErro, MensagemErro, NumeroErro, LinhaErro, EtapaErro)
		Values (
			@IdExecucao,
			@NomeProcedure,
			Dateadd(hour,-3,Getdate()),
			@MensagemErro,
			@NumeroErro,
			@LinhaErro,
			@EtapaErro
		);
	end

	/* Captura atualização de execução */
	If @TipoLog = 'Atualizacao'
	Begin
		
		Update a
		Set DataHoraFim = @DataHoraFim,
			StatusExecucao = @StatusExecucao,
			TempoExecucaoSegundos = Datediff(Second, DataHoraInicio, @DataHoraFim)
		From [log].ControleExecucoes a
		Where
			IdExecucao = @IdExecucao;

	end

	/* Captura execuções de expurgo */
	If @TipoLog = 'Expurgo'
	Begin 
		
		Insert into log.ControleExpurgo (IdTabelaExpurgo, NomeTabela, DataExecucao)
		Values (
			@IdTabelaExpurgo,
			@NomeTabela,
			Dateadd(hour,-3,Getdate())
		);

	End

end;
