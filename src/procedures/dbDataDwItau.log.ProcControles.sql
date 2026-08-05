
Create or Alter procedure [log].[ProcControles]
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
	@linhasTotaisDestino int = null,
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
	
		Insert into dbDataDwItau.[log].ControleExecucoes (NomeProcedure, DataHoraInicio, StatusExecucao)
		Values (
			@NomeProcedure,
			@DataHoraInicio,
			@StatusExecucao
		);

		Set @IdExecucao = scope_identity();
	end

	/* Captura volumetria de tabelas */
	If @TipoLog = 'Volumetria'
	Begin
		Insert into dbDataDwItau.[log].ControleVolumes (IdExecucao, NomeTabelaOrigem, NomeTabelaDestino, LinhasOrigem, LinhasInseridas, LinhasAtualizadas, LinhasTotaisDestino, DataExecucao)
		Values (
			@IdExecucao,
			@NomeTabelaOrigem,
			@NomeTabelaDestino,
			isnull(@LinhasOrigem, 0),
			isnull(@LinhasInseridas, 0),
			isnull(@LinhasAtualizadas, 0),
			isnull(@linhasTotaisDestino, 0),
			Getdate()
		);
	end

	/* Captura erros de execuções */
	If @TipoLog = 'Erro'
	Begin
		Insert into dbDataDwItau.[log].ControleErros (IdExecucao, NomeProcedure, DataErro, MensagemErro, NumeroErro, LinhaErro, EtapaErro)
		Values (
			@IdExecucao,
			@NomeProcedure,
			Getdate(),
			@MensagemErro,
			@NumeroErro,
			@LinhaErro,
			@EtapaErro
		);
	end

	/* Captura atualização de execucao */
	If @TipoLog = 'Atualizacao'
	Begin
		Update a
		Set DataHoraFim = @DataHoraFim,
			StatusExecucao = @StatusExecucao,
			TempoExecucaoSegundos = Datediff(Second, DataHoraInicio, @DataHoraFim)
		From misitau.[log].ControleExecucoes a
		Where 
			IdExecucao = @IdExecucao;

	end

	/* Captura execucoes de expurgo */
	If @TipoLog = 'Expurgo'
	Begin
		Insert into dbDataDwItau.log.ControleExpurgo (IdTabelaExpurgo, NomeTabela, DataExecucao)
		Values(
			@IdTabelaExpurgo,
			@NomeTabela,
			Getdate()
		);
	end

end;