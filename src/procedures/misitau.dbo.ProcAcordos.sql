Create or Alter Procedure dbo.ProcAcordos as 

------------------------------> Descrição da procedure

/*
	Padrão de escrita: PascalCase
	Nome: ProcAcordos
	DataCriação: 24/07/2026
	Criado por: Leonardo Matheus Talarico
	DataAtualização:
	Atualizado por:

	Descrição atualização: (Data, Atualizado por, Descrição, git)
*/

------------------------------> Definições de variaveis e controles de ambiente

Set Nocount On;

Declare @NomeProcedure varchar(128) = 'ProcAcordos',
        @Etapa varchar(100) = 'Inicio',
		@UltimaAtualizacao datetime,
		@DataPagamento datetime,
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

--------------------------------> Criacao de tabelas temporarias

Set @Etapa = 'Criacao das tabelas temporarias';

--- | Acordos

If Object_id('Tempdb..#Acordos') Is not null Drop table #Acordos;
Create table #Acordos (
	IdAcordo int,
	IdTipoAcordo tinyint,
	IdDevedor int,
	Plano tinyint,
	IdNegociadorResponsavel int,
	DataInclusao datetime,
	IdUsuarioInclusao int,
	Proposta char(1),
	DataAprovacaoProposta datetime,
	IdStatusAcordo tinyint,
	CodigoAcordoCliente varchar(64),
	DataCancelamento datetime,
	IdUsuarioCancelamento int
);

------------------------------> Carga das tabelas temporarias

Set @Etapa = 'Carga das tabelas temporarias';

--- | Insere novos acordos e acordos atualizados

Set @UltimaAtualizacao = (Select 
                            Case
                                when Datepart(hour,Max(DataHoraInicio)) >= 22 then Max(Dateadd(day,+1,Convert(date,DataHoraInicio)))
                                else Max(Convert(date,DataHoraInicio))
                            end
                          From misitau.[log].ControleExecucoes
                          Where
							NomeProcedure = 'ProcAcordos'
							and StatusExecucao = 'Concluida');
Set @DataPagamento = Case
						when Datepart(dw,@UltimaAtualizacao) = 2 then Convert(date,Dateadd(day,-3,@UltimaAtualizacao))
						else Convert(date,Dateadd(day,-1,@UltimaAtualizacao))
					 end;

Insert into #Acordos (
					IdAcordo,
					IdTipoAcordo,
					IdDevedor,
					Plano,
					IdNegociadorResponsavel,
					DataInclusao,
					IdUsuarioInclusao,
					Proposta,
					DataAprovacaoProposta,
					IdStatusAcordo,
					CodigoAcordoCliente,
					DataCancelamento,
					IdUsuarioCancelamento
					)
Select
	IdAcordo,
	IdTipoAcordo,
	IdDevedor,
	Plano,
	IdNegociadorResponsavel,
	DataInclusao,
	IdUsuarioInclusao,
	Proposta,
	DataAprovacaoProposta,
	IdStatusAcordo,
	CodigoAcordoCliente,
	DataCancelamento,
	IdUsuarioCancelamento
From misitau.cob.Acordos a
Where
	(DataInclusao >= @UltimaAtualizacao
	or DataCancelamento >= @UltimaAtualizacao
	or DataAprovacaoProposta >= @UltimaAtualizacao)
	and Not exists (Select 1
					From misitau.dbo.Acordos b With(nolock)
					Where
						a.IdAcordo = b.IdAcordo)

union

Select
	a.IdAcordo,
	IdTipoAcordo,
	IdDevedor,
	Plano,
	IdNegociadorResponsavel,
	DataInclusao,
	IdUsuarioInclusao,
	Proposta,
	DataAprovacaoProposta,
	IdStatusAcordo,
	CodigoAcordoCliente,
	DataCancelamento,
	IdUsuarioCancelamento
From misitau.cob.Acordos a
Where
	Exists (Select 1
			From misitau.cob.AcordosParcelasPagar b
			Where
				a.IdAcordo = b.IdAcordo
				and b.DataPagamento >= @DataPagamento)
	and Not exists (Select 1
					From misitau.dbo.Acordos c With(nolock)
					Where
						a.IdAcordo = c.IdAcordo
						and a.IdStatusAcordo = c.IdStatusAcordo);

Set @LinhasOrigem = @@RowCount;

------------------------------> Criacao de índices

Set @Etapa = 'Criacao de indices';

/* Cria index não clusterizado */
Create nonclustered index IxAcordos on #Acordos (IdAcordo);

------------------------------> Persistencia final

Set @Etapa = 'Persistencia final';

--- | Tabela fisica

Insert into misitau.dbo.Acordos (
						IdAcordo,
						IdTipoAcordo,
						IdDevedor,
						Plano,
						IdNegociadorResponsavel,
						DataInclusao,
						IdUsuarioInclusao,
						Proposta,
						DataAprovacaoProposta,
						IdStatusAcordo,
						CodigoAcordoCliente,
						DataCancelamento,
						IdUsuarioCancelamento
						)
Select distinct
	IdAcordo,
	IdTipoAcordo,
	IdDevedor,
	Plano,
	IdNegociadorResponsavel,
	DataInclusao,
	IdUsuarioInclusao,
	Proposta,
	DataAprovacaoProposta,
	IdStatusAcordo,
	CodigoAcordoCliente,
	DataCancelamento,
	IdUsuarioCancelamento
From #Acordos a With(nolock)
Where
	Not exists (Select 1
				From misitau.dbo.Acordos b With(nolock)
				Where
					a.IdAcordo = b.IdAcordo);

Set @LinhasInseridas = @@RowCount;

------------------------------> Atualizacao de dados

Set @Etapa = 'Atualizacao de dados';

--- | Atualiza campos da tabela fisica

Update a
Set a.DataAprovacaoProposta = b.DataAprovacaoProposta,
	a.IdStatusAcordo = b.IdStatusAcordo,
	a.CodigoAcordoCliente = b.CodigoAcordoCliente,
	a.DataCancelamento = b.DataCancelamento,
	a.IdUsuarioCancelamento = b.IdUsuarioCancelamento
From misitau.dbo.Acordos a With(nolock)
Inner join #Acordos b With(nolock) on a.IdAcordo = b.IdAcordo
Where
	Isnull(a.DataAprovacaoProposta,'1900-01-01') <> Isnull(b.DataAprovacaoProposta,'1900-01-01')
	or a.IdStatusAcordo <> b.IdStatusAcordo
	or Isnull(a.DataCancelamento,'1900-01-01') <> Isnull(b.DataCancelamento,'1900-01-01');

Set @LinhasAtualizadas = @@RowCount;
Set @LinhasTotaisDestino = @LinhasInseridas + @LinhasAtualizadas;
Set @DataHoraFim = Dateadd(hour,-3,Getdate());

/* Grava volumetria controles de log */
Exec misitau.[log].ProcControles
    @TipoLog = 'Volumetria',
    @IdExecucao = @IdExecucao,
    @NomeTabelaOrigem = 'cob.Acordos',
    @NomeTabelaDestino = 'dbo.Acordos',
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