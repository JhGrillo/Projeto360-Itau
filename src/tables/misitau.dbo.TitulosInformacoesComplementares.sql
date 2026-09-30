Create or Alter procedure [dbo].[ProcTitulosInformacoesComplementares] as 

------------------------------> Descrição da procedure

/*
	Padrão de escrita: PascalCase
	Nome: ProcTitulosInformacoesComplementares
	DataCriação: 23/07/2026
	Criado por: Leonardo Matheus Talarico
	DataAtualização: 30/09/2026
	Atualizado por: João Henrique Cavalheiro Grillo

	Descrição atualização: (Data, Atualizado por, Descrição, git)

	30/07/2026 João Henrique Cavalheiro Grillo: Refatoramento para melhoria de performance, foi criado um novo index na tabela de origem para melhorar o Not Exists, e adicionado
	uma temporaria antes com carregamento apenas dos dados novos ou atualizado para depois realizar o filtro comparativo com o destino.

	30/09/2026 João Henrique Cavalheiro Grillo: Foi removido colunas que não eram utilizadas para diminuir o uso de armazenamento da tabela no banco de dados.
*/

------------------------------> Definições de variaveis e controles de ambiente

Set Nocount On;

Declare @NomeProcedure varchar(128) = 'ProcTitulosInformacoesComplementares',
        @Etapa varchar(100) = 'Inicio',
		@IdTituloInformacaoComplementar int,
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
    @IdExecucao = @IdExecucao OUTPUT;

Begin Try

------------------------------> Criacao de tabelas temporarias

Set @Etapa = 'Criacao das tabelas temporarias';

--- | Origem

If Object_id('Tempdb..#DadosOrigem') Is not null Drop table #DadosOrigem;
Create table #DadosOrigem (
	IdTituloInformacaoComplementar int,
	DataInclusao datetime,
	IdUsuarioInclusao int,
	DataAtualizacao datetime,
	IdUsuarioAtualizacao int,
	IdTitulo int,
	ValorContratoAtualizado money,
	FaseCobranca char(2),
	NumeroCartao varchar(16),
	DataExclusao datetime,
	IdUsuarioExclusao int,
	ValidoDe datetime2,
	ValidoAte datetime2,
	AreaNegocio varchar(2),
	CodigoClusterScore varchar(4)
);

--- | Titulos informações complementares

If Object_id('Tempdb..#TitulosInformacoesComplementares') Is not null Drop table #TitulosInformacoesComplementares;
Create table #TitulosInformacoesComplementares (
	IdTituloInformacaoComplementar int,
	DataInclusao datetime,
	IdUsuarioInclusao int,
	DataAtualizacao datetime,
	IdUsuarioAtualizacao int,
	IdTitulo int,
	ValorContratoAtualizado money,
	FaseCobranca char(2),
	NumeroCartao varchar(16),
	DataExclusao datetime,
	IdUsuarioExclusao int,
	ValidoDe datetime2,
	ValidoAte datetime2,
	AreaNegocio varchar(2),
	CodigoClusterScore varchar(4)
);

------------------------------> Carga das tabelas temporarias

Set @Etapa = 'Carga das tabelas temporarias';

--- | Insere novos titulos na tabela

Set @IdTituloInformacaoComplementar = (Select Max(IdTituloInformacaoComplementar) From misitau.dbo.TitulosInformacoesComplementares With(nolock));
Set @UltimaAtualizacao = (Select 
							Case
								when Datepart(hour,Max(DataHoraInicio)) >= 22 then Max(Dateadd(day,-2,Convert(date,DataHoraInicio)))
                                else Max(Convert(date,DataHoraInicio - 1))
							end
                         From misitau.[log].ControleExecucoes
                         Where
                            NomeProcedure = 'ProcTitulosInformacoesComplementares'
                            and StatusExecucao = 'Concluida');

Insert into #DadosOrigem (
						IdTituloInformacaoComplementar,
						DataInclusao,
						IdUsuarioInclusao,
						DataAtualizacao,
						IdUsuarioAtualizacao,
						IdTitulo,
						ValorContratoAtualizado,
						FaseCobranca,
						NumeroCartao,
						DataExclusao,
						IdUsuarioExclusao,
						ValidoDe,
						ValidoAte,
						AreaNegocio,
						CodigoClusterScore
						)
Select
	IdTituloInformacaoComplementar,
	DataInclusao,
	IdUsuarioInclusao,
	DataAtualizacao,
	IdUsuarioAtualizacao,
	IdTitulo,
	ValorContratoAtualizado,
	FaseCobranca,
	NumeroCartao,
	DataExclusao,
	IdUsuarioExclusao,
	ValidoDe,
	ValidoAte,
	AreaNegocio,
	CodigoClusterScore
From misitau.cli.TitulosInformacoesComplementares a
Where
	IdTituloInformacaoComplementar > Isnull(@IdTituloInformacaoComplementar,0)
	or DataAtualizacao >= @UltimaAtualizacao;

/* Cria index clusterizado 
Obs: Este index é criado fora da etapa de index devido a necessidade de performance no comparativo abaixo.
*/
Create nonclustered index IxTituloInformacaoComplementar on #DadosOrigem (IdTituloInformacaoComplementar, DataAtualizacao);

--- | Titulos informacoes complementares

Insert into #TitulosInformacoesComplementares (
												IdTituloInformacaoComplementar,
												DataInclusao,
												IdUsuarioInclusao,
												DataAtualizacao,
												IdUsuarioAtualizacao,
												IdTitulo,
												ValorContratoAtualizado,
												FaseCobranca,
												NumeroCartao,
												DataExclusao,
												IdUsuarioExclusao,
												ValidoDe,
												ValidoAte,
												AreaNegocio,
												CodigoClusterScore
											)
Select
	IdTituloInformacaoComplementar,
	DataInclusao,
	IdUsuarioInclusao,
	DataAtualizacao,
	IdUsuarioAtualizacao,
	IdTitulo,
	ValorContratoAtualizado,
	FaseCobranca,
	NumeroCartao,
	DataExclusao,
	IdUsuarioExclusao,
	ValidoDe,
	ValidoAte,
	AreaNegocio,
	CodigoClusterScore
From #DadosOrigem a
Where
	Not exists (Select 1
				From misitau.dbo.TitulosInformacoesComplementares b
				Where
					a.IdTituloInformacaoComplementar = b.IdTituloInformacaoComplementar
					and Isnull(a.DataAtualizacao,'1900-01-01') = Isnull(b.DataAtualizacao,'1900-01-01'));

Set @LinhasOrigem = @@RowCount;

------------------------------> Criacao de índices

Set @Etapa = 'Criacao de indices';

/* Cria index não clusterizado */
Create nonclustered index IxTitulo on #TitulosInformacoesComplementares (IdTituloInformacaoComplementar);

------------------------------> Persistencia final

Set @Etapa = 'Persistencia final';

--- | Tabela fisica

Insert into misitau.dbo.TitulosInformacoesComplementares (
															IdTituloInformacaoComplementar,
															DataInclusao,
															IdUsuarioInclusao,
															DataAtualizacao,
															IdUsuarioAtualizacao,
															IdTitulo,
															ValorContratoAtualizado,
															FaseCobranca,
															NumeroCartao,
															DataExclusao,
															IdUsuarioExclusao,
															ValidoDe,
															ValidoAte,
															AreaNegocio,
															CodigoClusterScore
                                                          )
Select distinct
	IdTituloInformacaoComplementar,
	DataInclusao,
	IdUsuarioInclusao,
	DataAtualizacao,
	IdUsuarioAtualizacao,
	IdTitulo,
	ValorContratoAtualizado,
	FaseCobranca,
	NumeroCartao,
	DataExclusao,
	IdUsuarioExclusao,
	ValidoDe,
	ValidoAte,
	AreaNegocio,
	CodigoClusterScore
From #TitulosInformacoesComplementares a With(nolock)
Where
	Not exists (Select 1
				From misitau.dbo.TitulosInformacoesComplementares b With(nolock)
				Where
					a.IdTituloInformacaoComplementar = b.IdTituloInformacaoComplementar);

Set @LinhasInseridas = @@RowCount;

------------------------------> Atualizacao de dados

Set @Etapa = 'Atualizacao de dados';

--- | Atualiza campos da tabela fisica

Update a
Set	a.DataAtualizacao = b.DataAtualizacao,
	a.IdUsuarioAtualizacao = a.IdUsuarioAtualizacao,
	a.ValorContratoAtualizado = b.ValorContratoAtualizado,
	a.FaseCobranca = b.FaseCobranca,
	a.NumeroCartao = b.NumeroCartao,
	a.DataExclusao = b.DataExclusao,
	a.IdUsuarioExclusao = b.IdUsuarioExclusao,
	a.ValidoDe = b.ValidoDe,
	a.ValidoAte = b.ValidoAte,
	a.AreaNegocio = b.AreaNegocio,
	a.CodigoClusterScore = b.CodigoClusterScore
From misitau.dbo.TitulosInformacoesComplementares a With(nolock)
Inner join #TitulosInformacoesComplementares b With(nolock) on a.IdTituloInformacaoComplementar = b.IdTituloInformacaoComplementar
Where
	Isnull(a.DataAtualizacao,'1900-01-01') <> Isnull(b.DataAtualizacao,'1900-01-01');

Set @LinhasAtualizadas = @@RowCount;
Set @LinhasTotaisDestino = @LinhasInseridas + @LinhasAtualizadas;
Set @DataHoraFim = Dateadd(hour,-3,Getdate());

/* Grava volumetria controles de log */
Exec misitau.[log].ProcControles
	@TipoLog = 'Volumetria',
	@IdExecucao = @IdExecucao,
	@NomeTabelaOrigem = 'cli.TitulosInformacoesComplementares',
	@NomeTabelaDestino = 'dbo.TitulosInformacoesComplementares',
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