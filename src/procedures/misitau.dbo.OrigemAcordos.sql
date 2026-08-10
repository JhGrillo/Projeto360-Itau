Create or alter procedure dbo.ProcOrigemAcordos as 

------------------------------> Descrição da procedure

/*
	Padrão de escrita: PascalCase
	Nome: ProcOrigemAcordos
	DataCriação: 07/08/2026
	Criado por: Leonardo Matheus Talarico
	DataAtualização: 
	Atualizado por: 

	Descrição atualização: (Data, Atualizado por, Descrição, git)

*/

------------------------------> Definições de variaveis e controles de ambiente

Set Nocount On;

Declare @NomeProcedure varchar(128) = 'ProcOrigemAcordos',
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

If Object_id('Tempdb..#DadosOrigem') Is not null Drop table #DadosOrigem
Create table #DadosOrigem (
	IdAcordo int,
	IdOrigemAcordo char(1)
)

--- | OrigemAcordos

If Object_id('Tempdb..#OrigemAcordos') Is not null Drop table #OrigemAcordos
Create table #OrigemAcordos (
	IdAcordo int,
	IdOrigemAcordo char(1)
)

------------------------------> Carga das tabelas temporarias

Set @Etapa = 'Carga das tabelas temporarias';

--- | Insere as Origens dos Acordos

With OrigemCTE as (
	Select
		a.IdAcordo,
		a.IdLigacao
	From misitau.dbo.Ocorrencias a With(nolock)
	Where
		a.IdAcordo is not null
)

Insert into #DadosOrigem (
							IdAcordo,
							IdOrigemAcordo
						   )
Select
	a.IdAcordo,
	Isnull(b.IdOrigemLigacao, 'H') as IdOrigemAcordo
From OrigemCTE a With(nolock)
Left join misitau.dbo.Ligacoes b With(nolock) on a.IdLigacao = b.IdLigacao
Where
	Not exists (Select 1
				From misitau.dbo.OrigemAcordos b With(nolock)
				Where
					a.IdAcordo = b.IdAcordo)

Set @LinhasOrigem = @@RowCount;

------------------------------> Criacao de índices

Set @Etapa = 'Criacao de indices';

/* Cria index não clusterizado */
Create nonclustered Index IxOrigemAcordos on #OrigemAcordos (IdAcordo);

------------------------------> Persistencia final

Set @Etapa = 'Persistencia final';

--- | Tabela fisica

Insert into misitau.dbo.OrigemAcordos
Select
	*
From #OrigemAcordos a
Where 
	Not exists (
				Select 1
				From misitau.dbo.OrigemAcordos b with(nolock)
				Where a.IdAcordo = b.IdAcordo)

Set @LinhasInseridas = @@RowCount;
Set @LinhasTotaisDestino = @LinhasInseridas;
Set @DataHoraFim = Dateadd(hour,-3,Getdate());
	
/* Grava volumetria controles de log */
Exec misitau.[log].ProcControles
    @TipoLog = 'Volumetria',
    @IdExecucao = @IdExecucao,
    @NomeTabelaDestino = 'dbo.OrigemAcordos',
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