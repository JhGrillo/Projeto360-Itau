Create or Alter Procedure dbo.ProcEventosInformacoesComplementares as 

------------------------------> Descrição da procedure

/*
	Padrão de escrita: PascalCase
	Nome: ProcEventosInformacoesComplementares
	DataCriação: 06/10/2026
	Criado por: Leonardo Matheus Talarico
	DataAtualização:
	Atualizado por:

	Descrição atualização: (Data, Atualizado por, Descrição, git)

*/

------------------------------> Definições de variaveis e controles de ambiente

Set Nocount On;

Declare @NomeProcedure varchar(128) = 'ProcEventosInformacoesComplementares',
        @Etapa varchar(100) = 'Inicio',
		@IdEvento int,
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

--- | Ocorrências

If Object_id('Tempdb..#EventosInformacoesComplementares') Is not null Drop table #EventosInformacoesComplementares;
Create table #EventosInformacoesComplementares (
	IdEvento int,
	IdOrigemLigacao char(1)
);

------------------------------> Carga das tabelas temporarias

Set @Etapa = 'Carga das tabelas temporarias';

--- | Insere novas ocorrências na tabela

Set @IdEvento = (Select Min(IdEvento) From misitau.dbo.Eventos with(nolock));

Insert into #EventosInformacoesComplementares (
												IdEvento,
												IdOrigemLigacao
											   )
Select
	IdEvento,
	IdOrigemLigacao
From misitau.cli.EventosInformacoesComplementares a
Where
	IdEvento >= @IdEvento
	and Not exists (Select 1
					From misitau.dbo.EventosInformacoesComplementares b With(nolock)
					Where
						a.IdEvento = b.IdEvento);

Set @LinhasOrigem = @@RowCount;

------------------------------> Criacao de índices

Set @Etapa = 'Criacao de indices';

/* Cria index não clusterizado */
Create nonclustered index IxEventoInformacoesComplementares on #EventosInformacoesComplementares (IdEvento);

------------------------------> Persistencia final

Set @Etapa = 'Persistencia final';

--- | Tabela fisica

Insert into misitau.dbo.EventosInformacoesComplementares (
														  IdEvento,
														  IdOrigemLigacao
														  )

Select
	IdEvento,
	IdOrigemLigacao
From #EventosInformacoesComplementares a With(nolock)
Where
	Not exists (Select 1
				From misitau.dbo.EventosInformacoesComplementares b With(nolock)
				Where
					a.IdEvento = b.IdEvento);

Set @LinhasInseridas = @@RowCount;
Set @LinhasTotaisDestino = @LinhasInseridas;
Set @DataHoraFim = Dateadd(hour,-3,Getdate());

/* Grava volumetria controles de log */
Exec misitau.[log].ProcControles
    @TipoLog = 'Volumetria',
    @IdExecucao = @IdExecucao,
    @NomeTabelaOrigem = 'cli.EventosInformacoesComplementares',
    @NomeTabelaDestino = 'dbo.EventosInformacoesComplementares',
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