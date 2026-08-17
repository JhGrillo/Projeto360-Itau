Create or Alter procedure itau.ProcVencimentos360 as

------------------------------> Descrição da procedure

/*
	Padrão de escrita: PascalCase
	Nome: ProcVencimentos360
	DataCriação: 10/08/2026
	Criado por: Leonardo Matheus Talarico
	DataAtualização: 17/08/2026
	Atualizado por: João Henrique Cavalheiro Grillo

	Descrição atualização: (Data, Atualizado por, Descrição, git)

	17/08/2026 João Henrique Cavalheiro Grillo: Realizado o refatoramento da procedure, consolidando o carregamento dos dados, e retirando updates que estavam prejudicando o
	tempo de execução.
*/

------------------------------> Definições de variaveis e controles de ambiente

Set Nocount On;

Declare @NomeProcedure varchar(128) = 'ProcVencimentos360',
        @Etapa varchar(100) = 'Inicio',
		@UltimaAtualizacao datetime,
		@DataPagamento datetime,
		@SQLAcordosInformacoesComplementares nvarchar(max),
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

------------------------------> Criacao de tabelas temporarias

Set @Etapa = 'Criacao das tabelas temporarias';

--- | Base

If Object_id('Tempdb..#Base') Is not null Drop table #Base;
Create table #Base (
	IdBase int,
	Data datetime,
	IdDevedor int,
	IdTitulo int
);

--- | Vencimentos

If Object_id('Tempdb..#Vencimentos') Is not null Drop table #Vencimentos;
Create table #Vencimentos (
	IdAcordo int,
	TipoAcordo varchar(32),
	IdDevedor int,
	IdTitulo int,
	Plano int,
	NumeroParcela int,
	Valor money,
	DataVencimento datetime,
	Referencia varchar(64),
	Proposta char(1),
	DataAprovacaoProposta datetime,
	StatusAcordo varchar(64),
	DataCancelamento datetime,
	IdOrigemAcordo char(2)
);

--- | Vencimentos final

If Object_id('Tempdb..#VencimentosFinal') Is not null Drop table #VencimentosFinal;
Create table #VencimentosFinal (
	IdBase int,
	Data datetime,
	IdAcordo int,
	TipoAcordo varchar(32),
	IdDevedor int,
	IdTitulo int,
	Plano int,
	NumeroParcela int,
	Valor money,
	Referencia varchar(64),
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
	Data >= Convert(date,Getdate());

--- | Vencimentos

Insert into #Vencimentos (
						  IdAcordo,
						  TipoAcordo,
						  IdDevedor,
						  IdTitulo,
						  Plano,
						  NumeroParcela,
						  Valor,
						  DataVencimento,
						  Referencia,
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
	d.DataVencimento,
	e.Referencia,
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
	d.DataVencimento = Convert(date,Getdate())
	or Convert(date,a.DataCancelamento) = Convert(date,Getdate());

--- | Vencimentos Final

Insert into #VencimentosFinal (
							IdBase,
							Data,
							IdAcordo,
							TipoAcordo,
							IdDevedor,
							IdTitulo,
							Plano,
							NumeroParcela,
							Valor,
							Referencia,
							Proposta,
							DataAprovacaoProposta,
							StatusAcordo,
							DataCancelamento,
							IdOrigemAcordo
							  )
Select
	b.IdBase,
	a.DataVencimento,
	a.IdAcordo,
	a.TipoAcordo,
	a.IdDevedor,
	a.IdTitulo,
	a.Plano,
	a.NumeroParcela,
	a.Valor,
	a.Referencia,
	a.Proposta,
	a.DataAprovacaoProposta,
	a.StatusAcordo,
	a.DataCancelamento,
	a.IdOrigemAcordo
From #Vencimentos a
Inner join #Base b on a.IdDevedor = b.IdDevedor
					  and a.IdTitulo = b.IdTitulo
					  and a.DataVencimento = b.Data;

Set @LinhasOrigem = @@RowCount;

------------------------------> Criacao de índices

Set @Etapa = 'Criacao de indices';

/* Cria index não clusterizado */
Create nonclustered Index IxVencimentosFinal on #VencimentosFinal (IdBase, IdDevedor, IdTitulo, IdAcordo, Data);

------------------------------> Persistencia final

Set @Etapa = 'Persistencia final';

--- | Tabela fisica

Insert into dbDataDwItau.itau.Vencimentos360 (
											IdBase,
											Data,
											IdAcordo,
											TipoAcordo,
											IdDevedor,
											IdTitulo,
											Plano,
											NumeroParcela,
											Valor,
											Referencia,
											Proposta,
											DataAprovacaoProposta,
											StatusAcordo,
											DataCancelamento,
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
	Valor,
	Referencia,
	Proposta,
	DataAprovacaoProposta,
	StatusAcordo,
	DataCancelamento,
	IdOrigemAcordo
From #VencimentosFinal a
Where
	not exists (
				Select 1
				From dbDataDwItau.itau.Vencimentos360 b With(nolock)
				Where 
					a.IdBase = b.IdBase
					and a.IdAcordo = b.IdAcordo
					and a.NumeroParcela = b.NumeroParcela);

Set @LinhasInseridas = @@RowCount;

------------------------------> Atualizacao de dados

Set @Etapa = 'Atualizacao de dados';

--- | Atualiza campos da tabela fisica

Update a
Set a.DataCancelamento = b.DataCancelamento
From dbDataDwItau.itau.Vencimentos360 a with(nolock)
inner join #VencimentosFinal b with(nolock) on a.IdBase = b.IdBase
											   and a.IdAcordo = b.IdAcordo
											   and a.NumeroParcela = b.NumeroParcela
Where
	b.DataCancelamento is not null
	and a.DataCancelamento is null;

Set @LinhasAtualizadas = @@RowCount;
Set @LinhasTotaisDestino = @LinhasInseridas + isnull(@LinhasAtualizadas, 0);
Set @DataHoraFim = Getdate();
	
/* Grava volumetria controles de log */
Exec dbDataDwItau.[log].ProcControles
    @TipoLog = 'Volumetria',
    @IdExecucao = @IdExecucao,
    @NomeTabelaDestino = 'dbo.OrigemAcordos',
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