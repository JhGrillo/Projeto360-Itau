Create or alter Procedure itau.ProcPagamentos360 as

------------------------------> Descrição da procedure

/*
	Padrão de escrita: PascalCase
	Nome: ProcPagamentos360
	DataCriação: 12/08/2026
	Criado por: Leonardo Matheus Talarico
	DataAtualização:
	Atualizado por:

	Descrição atualização: (Data, Atualizado por, Descrição, git)

*/

------------------------------> Definições de variaveis e controles de ambiente

Set Nocount On;

Declare @NomeProcedure varchar(128) = 'ProcPagamentos360',
        @Etapa varchar(100) = 'Inicio',
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
	IdDevedor int,
	IdAcordo int,
	IdTitulo int,
	NumeroParcela int,
	ValorPago money,
	Valor money,
	IdNegociadorResponsavel varchar(32),
	TipoAcordo varchar(32),
	DataCancelamento datetime,
	IdOrigemAcordo char(1)
);

--- | Usuarios

if object_id('Tempdb..#Usuarios') Is not null Drop Table #Usuarios;
Create table #Usuarios (
	IdUsuario int,
	Referencia varchar(32)
);

--- | Pagamentos Final

if object_id('Tempdb..#PagamentosFinal') Is not null Drop Table #PagamentosFinal;
Create table #PagamentosFinal (
	IdBase int,
	Data datetime,
	IdDevedor int,
	IdTitulo int,
	IdAcordo int,
	NumeroParcela int,
	ValorPago money,
	Valor money,
	Referencia varchar(32),
	TipoAcordo varchar(32),
	DataCancelamento datetime,
	IdOrigemAcordo char(1)
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
	Data >= Convert(date, Getdate())

--- | Pagamentos

Insert into #Pagamentos (
						 IdDevedor,
						 IdAcordo,
						 IdTitulo,
						 NumeroParcela,
						 ValorPago,
						 Valor,
						 IdNegociadorResponsavel,
						 TipoAcordo,
						 DataCancelamento,
						 IdOrigemAcordo
						)
Select
	*
From openquery (misitau,'
Select
	a.IdDevedor,
	a.IdAcordo,
	c.IdTitulo,
	b.NumeroParcela,
	b.ValorPago,
	b.Valor,
	a.IdNegociadorResponsavel,
	a.IdTipoAcordo,
	a.DataCancelamento,
	d.IdOrigemAcordo
From misitau.dbo.Acordos a With(nolock)
inner join misitau.dbo.AcordosParcelasPagar b With(nolock) on a.IdAcordo = b.IdAcordo
inner join misitau.dbo.AcordosParcelasNegociadas c With(nolock) on a.IdAcordo = c.IdAcordo
Left Join misitau.dbo.OrigemAcordos d With(nolock) on a.IdAcordo = d.IdAcordo
Where
	b.DataPagamento >= Convert(date, Getdate()-5)
	or a.DataCancelamento >= Convert(date, Getdate());');

--- | Usuarios

Insert into #Usuarios (
					   IdUsuario,
					   Referencia
					  )
Select
	*
From openquery (misitau,'
Select 
	IdUsuario,
	Referencia
From misitau.dbo.Usuarios With(nolock);');

--- | Pagamentos Final

Insert into #PagamentosFinal (
							  IdBase,
							  Data,
							  IdDevedor,
							  IdTitulo,
							  IdAcordo,
							  NumeroParcela,
							  ValorPago,
							  Valor,
							  Referencia,
							  TipoAcordo,
							  DataCancelamento,
							  IdOrigemAcordo
							 )
Select
	a.IdBase,
	a.Data,
	a.IdDevedor,
	a.IdTitulo,
	b.IdAcordo,
	b.NumeroParcela,
	b.ValorPago,
	b.Valor,
	c.Referencia,
	b.TipoAcordo,
	b.DataCancelamento,
	b.IdOrigemAcordo
From #Base a
inner join #Pagamentos b on a.IdDevedor = b.IdDevedor
							and a.IdTitulo = b.IdTitulo
inner join #Usuarios c on b.IdNegociadorResponsavel = c.IdUsuario

Set @LinhasOrigem = @@RowCount;

------------------------------> Criacao de índices

Set @Etapa = 'Criacao de indices';

/* Cria index não clusterizado */
Create nonclustered index IxPagamentos on #PagamentosFinal (IdAcordo, IdDevedor, IdTitulo, Data)

------------------------------> Persistencia final

Set @Etapa = 'Persistencia final';

--- | Tabela fisica

Insert into dbDataDwItau.itau.Pagamentos360 (
											 IdBase,
											 Data,
											 IdDevedor,
											 IdTitulo,
											 IdAcordo,
											 NumeroParcela,
											 ValorPago,
											 Valor,
											 Referencia,
											 TipoAcordo,
											 DataCancelamento,
											 IdOrigemAcordo
											)
Select
	IdBase,
	Data,
	IdDevedor,
	IdTitulo,
	IdAcordo,
	NumeroParcela,
	ValorPago,
	Valor,
	Referencia,
	TipoAcordo,
	DataCancelamento,
	IdOrigemAcordo
From #PagamentosFinal a
Where
	not exists (Select 1
				From dbDataDwItau.itau.Pagamentos360 b With(nolock)
				Where 
					a.IdAcordo = b.IdAcordo
					and a.IdDevedor = b.IdDevedor
					and a.IdTitulo = b.IdTitulo
					and a.Data = b.Data)

Set @LinhasInseridas = @@RowCount;

------------------------------> Atualizacao de dados

Set @Etapa = 'Atualizacao de dados';

--- | Atualiza campos da tabela fisica

Update a
Set a.DataCancelamento = b.DataCancelamento
From dbDataDwItau.itau.Pagamentos360 a With(nolock)
inner join #PagamentosFinal b on a.IdAcordo = b.IdAcordo
Where
	b.DataCancelamento >= Convert(date, Getdate())
	and a.DataCancelamento is null;

Set @LinhasAtualizadas = @@RowCount;
Set @LinhasTotaisDestino = @LinhasInseridas + isnull(@LinhasAtualizadas, 0);
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