Create or Alter procedure dbo.ProcDevedoresInformacoesComplementares as

------------------------------> Descrição da procedure

/*
	Padrão de escrita: PascalCase
	Nome: ProcDevedoresInformacoesComplementares
	DataCriação: 23/07/2026
	Criado por: João Henrique Cavalheiro Grillo
	DataAtualização:
	Atualizado por:

	Descrição atualização: (Data, Atualizado por, Descrição, git)
*/

------------------------------> Definições de variaveis e controles de ambiente

Set nocount on;

Declare @NomeProcedure varchar(128) = 'ProcDevedoresInformacoesComplementares',
		@Etapa varchar(100) = 'Inicio',
		@IdDevedorInformacaoComplementar int,
		@UltimaAtualizacao datetime,
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
	@IdExecucao = @IdExecucao OUTPUT

Begin try

------------------------------> Criacao das tabelas temporarias

Set @Etapa = 'Criacao das tabelas temporarias';

--- | Devedores informações complementares

If Object_id('Tempdb..#DevedoresInformacoesComplementares') Is not null Drop table #DevedoresInformacoesComplementares;
Create table #DevedoresInformacoesComplementares (
	IdDevedorInformacaoComplementar int,
	DataInclusao datetime,
	IdUsuarioInclusao int,
	DataAtualizacao datetime,
	IdUsuarioAtualizacao int,
	IdDevedor int,
	DataNascimento smalldatetime,
	SexoCliente char(1),
	ValidoDe datetime2,
	ValidoAte datetime2
);

------------------------------> Carga das tabelas temporarias

Set @Etapa = 'Carga das tabelas temporarias';

--- | Insere devedores novos ou atualizados

Set @IdDevedorInformacaoComplementar = (Select Max(IdDevedorInformacaoComplementar) From misitau.dbo.DevedoresInformacoesComplementares With(nolock));
Set @UltimaAtualizacao = (Select 
                            Case
                                when Datepart(hour,Max(DataHoraInicio)) >= 22 then Max(Dateadd(day,+1,Convert(date,DataHoraInicio)))
                                else Max(Convert(date,DataHoraInicio))
                            end
                          From misitau.[log].ControleExecucoes
                          Where
                            NomeProcedure = 'ProcDevedoresInformacoesComplementares'
                            and StatusExecucao = 'Concluida');

Insert into #DevedoresInformacoesComplementares (
												IdDevedorInformacaoComplementar,
												DataInclusao,
												IdUsuarioInclusao,
												DataAtualizacao,
												IdUsuarioAtualizacao,
												IdDevedor,
												DataNascimento,
												SexoCliente,
												ValidoDe,
												ValidoAte
												)
Select
	IdDevedorInformacaoComplementar,
	DataInclusao,
	IdUsuarioInclusao,
	DataAtualizacao,
	IdUsuarioAtualizacao,
	IdDevedor,
	DataNascimento,
	SexoCliente,
	ValidoDe,
	ValidoAte
From misitau.cli.DevedoresInformacoesComplementares a
Where
	(IdDevedorInformacaoComplementar > @IdDevedorInformacaoComplementar
	or DataAtualizacao >= @UltimaAtualizacao)
	and Not exists (Select 1
					From misitau.dbo.DevedoresInformacoesComplementares b With(nolock)
					Where
						a.IdDevedor = b.IdDevedor
						and Isnull(a.DataAtualizacao,'1900-01-01') = Isnull(b.DataAtualizacao,'1900-01-01'))

Set @LinhasOrigem = @@RowCount;

------------------------------> Criacao de indices

Set @Etapa = 'Criacao de indices';

/* Cria index não clusterizado */
Create nonclustered index IxDevedorInformacaoComplementar on #DevedoresInformacoesComplementares (IdDevedorInformacaoComplementar);

------------------------------> Persistencia final

Set @Etapa = 'Persistencia final';

--- | Tabela fisica

Insert into misitau.dbo.DevedoresInformacoesComplementares (
													IdDevedorInformacaoComplementar,
													DataInclusao,
													IdUsuarioInclusao,
													DataAtualizacao,
													IdUsuarioAtualizacao,
													IdDevedor,
													DataNascimento,
													SexoCliente,
													ValidoDe,
													ValidoAte
													)
Select distinct
	IdDevedorInformacaoComplementar,
	DataInclusao,
	IdUsuarioInclusao,
	DataAtualizacao,
	IdUsuarioAtualizacao,
	IdDevedor,
	DataNascimento,
	SexoCliente,
	ValidoDe,
	ValidoAte
From #DevedoresInformacoesComplementares a With(nolock)
Where
	Not exists (Select 1
				From misitau.dbo.DevedoresInformacoesComplementares b With(nolock)
				Where
					a.IdDevedorInformacaoComplementar = b.IdDevedorInformacaoComplementar);

Set @LinhasInseridas = @@RowCount;

------------------------------> Atualizacao de dados

Set @Etapa = 'Atualizacao de dados';

--- | Atualiza campos da tabela fisica

Update a
Set a.DataInclusao = b.DataInclusao,
	a.IdUsuarioInclusao = b.IdUsuarioInclusao,
	a.DataAtualizacao = b.DataAtualizacao,
	a.IdUsuarioAtualizacao = b.IdUsuarioAtualizacao,
	a.IdDevedor = b.IdDevedor,
	a.DataNascimento = b.DataNascimento,
	a.SexoCliente = b.SexoCliente,
	a.ValidoDe = b.ValidoDe,
	a.ValidoAte = b.ValidoAte
From misitau.dbo.DevedoresInformacoesComplementares a With(nolock)
Inner join #DevedoresInformacoesComplementares b With(nolock) on a.IdDevedorInformacaoComplementar = b.IdDevedorInformacaoComplementar
Where
	Isnull(a.DataAtualizacao,'1900-01-01') <> Isnull(b.DataAtualizacao,'1900-01-01');

Set @LinhasAtualizadas = @@RowCount;
Set @LinhasTotaisDestino = @LinhasInseridas + @LinhasAtualizadas;
Set @DataHoraFim = Dateadd(hour,-3,Getdate());

/* Grava volumetria controles de log */
Exec misitau.[log].ProcControles
	@TipoLog = 'Volumetria',
	@IdExecucao = @IdExecucao,
	@NomeTabelaOrigem = 'cli.DevedoresInformacoesComplementares',
	@NomeTabelaDestino = 'dbo.DevedoresInformacoesComplementares',
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


End try
Begin Catch

Set @MensagemErro = Error_message();
Set @NumeroErro = Error_number();
Set @LinhaErro = Error_line()

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