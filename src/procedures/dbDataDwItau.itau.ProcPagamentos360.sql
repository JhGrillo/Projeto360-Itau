Create or Alter Procedure itau.ProcPagamentos360 as 

------------------------------> Descrição da procedure

/*
	Padrão de escrita: PascalCase
	Nome: ProcPagamentos360
	DataCriação: 12/08/2026
	Criado por: Leonardo Matheus Talarico
	DataAtualização: 17/08/2026
	Atualizado por: João Henrique Cavalheiro Grillo

	Descrição atualização: (Data, Atualizado por, Descrição, git)
	17/08/2026 João Henrique Cavalheiro Grillo: Refatoramento da procedure com busca de melhoria no tempo de execução e elegebilidade do código.

	31/08/2026 Leonardo Matheus Talarico: Foi feito uma alteração na procedure, onde será considerado como Origem as linhas que não estão presentes na tabela
	de Pagamentos360, para evitar divergencia entre as linhas de origem com as de destino

*/

------------------------------> Definições de variaveis e controles de ambiente

Set Nocount On;

Declare @NomeProcedure varchar(128) = 'ProcPagamentos360',
        @Etapa varchar(100) = 'Inicio',
        @IdExecucao int,
		@DataPagamento datetime,
        @LinhasOrigem int,
        @LinhasInseridas int,
        @LinhasAtualizadas int,
        @LinhasTotaisDestino int,
        @DataHoraInicio datetime = Getdate(),
        @DataHoraFim datetime,
        @MensagemErro varchar(max),
        @NumeroErro int,
        @LinhaErro int;

/* Inicia o controle de logs */
Exec dbDataDwItau.[log].ProcControles
    @TipoLog = 'Execucao',
    @NomeProcedure = @NomeProcedure,
    @DataHoraInicio = @DataHoraInicio,
    @StatusExecucao = 'Executando',
    @IdExecucao = @IdExecucao OUTPUT;

Begin Try

--------------------------------> Criacao de tabelas temporarias

Set @Etapa = 'Criacao das tabelas temporarias';

--- | Base

if object_id('Tempdb..#Base') Is not null Drop Table #Base;
Create table #Base (
	IdBase int,
	Data datetime,
	IdDevedor int,
	IdTitulo int
);

--- | Pagamentos

if object_id('Tempdb..#Pagamentos') Is not null Drop Table #Pagamentos;
Create table #Pagamentos (
	IdAcordo int,
	TipoAcordo varchar(32),
	IdDevedor int,
	IdTitulo int,
	Plano int,
	NumeroParcela int,
	DataPagamento datetime,
	ValorPago money,
	Referencia varchar(64),
	Proposta char(1),
	DataAprovacaoProposta datetime,
	StatusAcordo varchar(64),
	IdOrigemAcordo char(2)
)

--- | Pagamentos Final

if object_id('Tempdb..#PagamentosFinal') Is not null Drop Table #PagamentosFinal;
Create table #PagamentosFinal (
	IdBase int,
	Data datetime,
	IdAcordo int,
	TipoAcordo varchar(32),
	IdDevedor int,
	IdTitulo int,
	Plano int,
	NumeroParcela int,
	ValorPago money,
	Referencia varchar(64),
	Proposta char(1),
	DataAprovacaoProposta datetime,
	StatusAcordo varchar(64),
	IdOrigemAcordo char(2)
);

------------------------------> Carga das tabelas temporarias

Set @Etapa = 'Carga das tabelas temporarias';

Set @DataPagamento = (Select Min(DataPagamento) From misitau.misitau.dbo.AcordosParcelasPagar With(nolock));

--- | Base

Insert into #Base (
				   IdBase,
				   Data,
				   IdDevedor,
				   IdTitulo
				  )
Select
	IdBase,
	Data,
	IdDevedor,
	IdTitulo
From dbDataDwItau.itau.Base360 With(nolock)
Where
	Data >= @DataPagamento;

--- | Pagamentos

Insert into #Pagamentos (
						 IdAcordo,
						 TipoAcordo,
						 IdDevedor,
						 IdTitulo,
						 Plano,
						 NumeroParcela,
						 DataPagamento,
						 ValorPago,
						 Referencia,
						 Proposta,
						 DataAprovacaoProposta,
						 StatusAcordo,
						 IdOrigemAcordo
						)
Select distinct
	a.IdAcordo,
	b.TipoAcordo,
	a.IdDevedor,
	c.IdTitulo,
	a.Plano,
	d.NumeroParcela,
	d.DataPagamento,
	d.ValorPago,
	e.Referencia,
	a.Proposta,
	a.DataAprovacaoProposta,
	f.StatusAcordo,
	g.IdOrigemAcordo
From misitau.misitau.dbo.Acordos a With(nolock)
Inner join misitau.misitau.dbo.TiposAcordos b With(nolock) on a.IdTipoAcordo = b.IdTipoAcordo
Inner join misitau.misitau.dbo.AcordosParcelasNegociadas c With(nolock) on a.IdAcordo = c.IdAcordo
Inner join misitau.misitau.dbo.AcordosParcelasPagar d With(nolock) on a.IdAcordo = d.IdAcordo
Inner join misitau.misitau.dbo.Usuarios e With(nolock) on a.IdNegociadorResponsavel = e.IdUsuario
Inner join misitau.misitau.dbo.StatusAcordos f With(nolock) on a.IdStatusAcordo = f.IdStatusAcordo
Inner join misitau.misitau.dbo.OrigemAcordos g With(nolock) on a.IdAcordo = g.IdAcordo
Where
	d.DataPagamento >= @DataPagamento;

--- | Pagamentos Final

Insert into #PagamentosFinal (
							IdBase,
							Data,
							IdAcordo,
							TipoAcordo,
							IdDevedor,
							IdTitulo,
							Plano,
							NumeroParcela,
							ValorPago,
							Referencia,
							Proposta,
							DataAprovacaoProposta,
							StatusAcordo,
							IdOrigemAcordo
							 )
Select
	b.IdBase,
	a.DataPagamento,
	a.IdAcordo,
	a.TipoAcordo,
	a.IdDevedor,
	a.IdTitulo,
	a.Plano,
	a.NumeroParcela,
	a.ValorPago,
	a.Referencia,
	a.Proposta,
	a.DataAprovacaoProposta,
	a.StatusAcordo,
	a.IdOrigemAcordo
From #Pagamentos a
inner join #Base b on a.IdDevedor = b.IdDevedor
					  and a.IdTitulo = b.IdTitulo
					  and a.DataPagamento = b.Data
Where
	not exists (Select 1
					From dbDataDwItau.itau.Pagamentos360 c With(nolock)
					Where 
						b.IdBase = c.IdBase
						and a.IdAcordo = c.IdAcordo
						and a.NumeroParcela = c.NumeroParcela);

Set @LinhasOrigem = @@RowCount;

------------------------------> Criacao de índices

Set @Etapa = 'Criacao de indices';

/* Cria index não clusterizado */
Create nonclustered index IxPagamentos on #PagamentosFinal (IdBase, IdAcordo, NumeroParcela);

------------------------------> Persistencia final

Set @Etapa = 'Persistencia final';

--- | Tabela fisica

Insert into dbDataDwItau.itau.Pagamentos360 (
											IdBase,
											Data,
											IdAcordo,
											TipoAcordo,
											IdDevedor,
											IdTitulo,
											Plano,
											NumeroParcela,
											ValorPago,
											Referencia,
											Proposta,
											DataAprovacaoProposta,
											StatusAcordo,
											IdOrigemAcordo
											)
Select
	IdBase,
	Data,
	IdAcordo,
	TipoAcordo,
	IdDevedor,
	IdTitulo,
	Plano,
	NumeroParcela,
	ValorPago,
	Referencia,
	Proposta,
	DataAprovacaoProposta,
	StatusAcordo,
	IdOrigemAcordo
From #PagamentosFinal a
Where
	not exists (Select 1
				From dbDataDwItau.itau.Pagamentos360 b With(nolock)
				Where 
					a.IdBase = b.IdBase
					and a.IdAcordo = b.IdAcordo
					and a.NumeroParcela = b.NumeroParcela);

Set @LinhasInseridas = @@RowCount;
Set @LinhasTotaisDestino = Isnull(@LinhasInseridas, 0);
Set @DataHoraFim = Getdate();

/* Grava volumetria controles de log */
Exec dbDataDwItau.[log].ProcControles
    @TipoLog = 'Volumetria',
    @IdExecucao = @IdExecucao,
    @NomeTabelaDestino = 'itau.Pagamentos360',
    @LinhasOrigem = @LinhasOrigem,
    @LinhasInseridas = @LinhasInseridas,
    @LinhasAtualizadas = @LinhasAtualizadas,
    @LinhasTotaisDestino = @LinhasTotaisDestino;

/* Finaliza execução controles de log concluido */
Exec dbDataDwItau.[log].ProcControles
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
Set @DataHoraFim = Getdate();
Exec dbDataDwItau.[log].ProcControles
    @TipoLog = 'Atualizacao',
    @IdExecucao = @IdExecucao,
    @DataHoraFim = @DataHoraFim,
    @StatusExecucao = 'Erro';

/* Execução log erro */
Exec dbDataDwItau.[log].ProcControles
    @TipoLog = 'Erro',
    @IdExecucao = @IdExecucao,
    @NomeProcedure = @NomeProcedure,
    @MensagemErro = @MensagemErro,
    @NumeroErro = @NumeroErro,
    @LinhaErro = @LinhaErro,
    @EtapaErro = @Etapa;

End Catch;