Create or Alter procedure itau.ProcAcordos360 as

------------------------------> Descrição da procedure

/*
	Padrão de escrita: PascalCase
	Nome: ProcAcordos360
	DataCriação: 07/08/2026
	Criado por: Leonardo Matheus Talarico
	DataAtualização: 17/08/2026
	Atualizado por: João Henrique Cavalheiro Grillo

	Descrição atualização: (Data, Atualizado por, Descrição, git)

	12/08/2026 Leonardo Matheus Talarico: Foi atualizado a forma que as informações de IdOrigemAcordos eram inseridas na tabela, para garantir uma boa performance nas jobs.

	17/08/2026 João Henrique Cavalheiro Grillo: Realizado o refatoramento da procedure, consolidando no carregamento dos dados as informações, e retirando updates que estava prejudicando
	o tempo de execução.
*/

------------------------------> Definições de variaveis e controles de ambiente

Set Nocount On;

Declare @NomeProcedure varchar(128) = 'ProcAcordos360',
        @Etapa varchar(100) = 'Inicio',
		@UltimaAtualizacao datetime,
		@DataPagamento datetime,
        @IdExecucao int,
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

If Object_id('Tempdb..#Base') Is not null Drop table #Base;
Create table #Base (
	IdBase int,
	Data datetime,
	IdDevedor int,
	IdTitulo int
);

--- | Acordos

If Object_id('Tempdb..#Acordos') Is not null Drop table #Acordos;
Create table #Acordos (
	IdAcordo int,
	TipoAcordo varchar(32),
	IdDevedor int,
	IdTitulo int,
	Plano int,
	NumeroParcela int,
	Valor money,
	Referencia varchar(64),
	DataInclusao datetime,
	Proposta char(1),
	DataAprovacaoProposta datetime,
	StatusAcordo varchar(64),
	DataCancelamento datetime,
	IdOrigemAcordo char(2)
);

--- | Acordos final

If Object_id('Tempdb..#AcordosFinal') Is not null Drop table #AcordosFinal;
Create table #AcordosFinal (
	IdBase int,
	IdAcordo int,
	TipoAcordo varchar(32),
	IdDevedor int,
	IdTitulo int,
	Plano int,
	NumeroParcela int,
	Valor money,
	Referencia varchar(64),
	DataInclusao datetime,
	Proposta char(1),
	DataAprovacaoProposta datetime,
	StatusAcordo varchar(64),
	DataCancelamento datetime,
	IdOrigemAcordo char(2)
);

------------------------------> Carga das tabelas temporarias

Set @Etapa = 'Carga das tabelas temporarias';

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
	Data >= Convert(date, Getdate());

--- | Acordos

Insert into #Acordos (
					  IdAcordo,
					  TipoAcordo,
					  IdDevedor,
					  IdTitulo,
					  Plano,
					  NumeroParcela,
					  Valor,
					  Referencia,
					  DataInclusao,
					  Proposta,
					  DataAprovacaoProposta,
					  StatusAcordo,
					  DataCancelamento,
					  IdOrigemAcordo
					 )
Select distinct
	a.IdAcordo,
	b.TipoAcordo,
	a.IdDevedor,
	c.IdTitulo,
	a.Plano,
	d.NumeroParcela,
	d.Valor,
	e.Referencia,
	a.DataInclusao,
	a.Proposta,
	a.DataAprovacaoProposta,
	f.StatusAcordo,
	a.DataCancelamento,
	g.IdOrigemAcordo
From misitau.misitau.dbo.Acordos a With(nolock)
Inner join misitau.misitau.dbo.TiposAcordos b With(nolock) on a.IdTipoAcordo = b.IdTipoAcordo
Inner join misitau.misitau.dbo.AcordosParcelasNegociadas c With(nolock) on a.IdAcordo = c.IdAcordo
Inner join misitau.misitau.dbo.AcordosParcelasPagar d With(nolock) on a.IdAcordo = d.IdAcordo
Inner join misitau.misitau.dbo.Usuarios e With(nolock) on a.IdNegociadorResponsavel = e.IdUsuario
Inner join misitau.misitau.dbo.StatusAcordos f With(nolock) on a.IdStatusAcordo = f.IdStatusAcordo
Inner join misitau.misitau.dbo.OrigemAcordos g With(nolock) on a.IdAcordo = g.IdAcordo
Where
	a.DataInclusao >= Convert(date,Getdate())
	or a.DataCancelamento >= Convert(date,Getdate())
	or a.DataAprovacaoProposta >= Convert(date,Getdate());

--- | Acordos final

Insert into #AcordosFinal (
						IdBase,
						IdAcordo,
						TipoAcordo,
						IdDevedor,
						IdTitulo,
						Plano,
						NumeroParcela,
						Valor,
						Referencia,
						DataInclusao,
						Proposta,
						DataAprovacaoProposta,
						StatusAcordo,
						DataCancelamento,
						IdOrigemAcordo
						)
Select
	b.IdBase,
	a.IdAcordo,
	a.TipoAcordo,
	a.IdDevedor,
	a.IdTitulo,
	a.Plano,
	a.NumeroParcela,
	a.Valor,
	a.Referencia,
	a.DataInclusao,
	a.Proposta,
	a.DataAprovacaoProposta,
	a.StatusAcordo,
	a.DataCancelamento,
	a.IdOrigemAcordo
From #Acordos a With(nolock)
Inner join #Base b With(nolock) on a.IdDevedor = b.IdDevedor
								   and a.IdTitulo = b.IdTitulo
								   and Convert(date,a.DataInclusao) = b.Data;

Set @LinhasOrigem = @@RowCount;

------------------------------> Criacao de índices

Set @Etapa = 'Criacao de indices';

/* Cria index não clusterizado */
Create nonclustered index IxAcordos360 on #AcordosFinal (IdBase, IdAcordo, NumeroParcela);

------------------------------> Persistencia final

Set @Etapa = 'Persistencia final';

--- | Tabela fisica

Insert into dbDataDwItau.itau.Acordos360 (
										IdBase,
										IdAcordo,
										TipoAcordo,
										IdDevedor,
										IdTitulo,
										Plano,
										NumeroParcela,
										Valor,
										Referencia,
										DataInclusao,
										Proposta,
										DataAprovacaoProposta,
										StatusAcordo,
										DataCancelamento,
										IdOrigemAcordo
										 )
Select 
	IdBase,
	IdAcordo,
	TipoAcordo,
	IdDevedor,
	IdTitulo,
	Plano,
	NumeroParcela,
	Valor,
	Referencia,
	DataInclusao,
	Proposta,
	DataAprovacaoProposta,
	StatusAcordo,
	DataCancelamento,
	IdOrigemAcordo
From #AcordosFinal a
Where 
	Not exists (Select 1
				From dbDataDwItau.itau.Acordos360 b With(nolock)
				Where 
					a.IdBase = b.IdBase
					and a.IdAcordo = b.IdAcordo
					and a.NumeroParcela = b.NumeroParcela);

Set @LinhasInseridas = @@RowCount;

------------------------------> Atualizacao de dados

Set @Etapa = 'Atualizacao de dados';

--- | Atualiza campos da tabela fisica

/* Atualiza a Proposta e Cancelamento */

Update a
Set a.Proposta = b.Proposta,
	a.DataAprovacaoProposta = b.DataAprovacaoProposta,
	a.StatusAcordo = b.StatusAcordo,
	a.DataCancelamento = b.DataCancelamento
From dbDataDwItau.itau.Acordos360 a With(nolock)
Inner join #AcordosFinal b With(nolock) on a.IdBase = b.IdBase
										   and a.IdAcordo = b.IdAcordo
										   and a.NumeroParcela = b.NumeroParcela
Where
	Isnull(a.DataAprovacaoProposta,'1900-01-01') <> Isnull(b.DataAprovacaoProposta,'1900-01-01')
	or a.StatusAcordo <> b.StatusAcordo
	or Isnull(a.DataCancelamento,'1900-01-01') <> Isnull(b.DataCancelamento,'1900-01-01');

Set @LinhasAtualizadas += @@RowCount;
Set @LinhasTotaisDestino = @LinhasInseridas + isnull(@LinhasAtualizadas, 0);
Set @DataHoraFim = Getdate();

/* Grava volumetria controles de log */
Exec dbDataDwItau.[log].ProcControles
    @TipoLog = 'Volumetria',
    @IdExecucao = @IdExecucao,
    @NomeTabelaDestino = 'itau.Acordos360',
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