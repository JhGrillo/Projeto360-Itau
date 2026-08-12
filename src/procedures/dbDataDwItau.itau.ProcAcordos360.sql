Create or alter Procedure itau.ProcAcordos360 as

------------------------------> Descrição da procedure

/*
	Padrão de escrita: PascalCase
	Nome: ProcAcordos360
	DataCriação: 07/08/2026
	Criado por: Leonardo Matheus Talarico
	DataAtualização: 12/08/2026
	Atualizado por: Leonardo Matheus Talarico

	Descrição atualização: (Data, Atualizado por, Descrição, git)

	12/08/2026 Leonardo Matheus Talarico: Foi atualizado a forma que as informações de IdOrigemAcordos eram inseridas na tabela, para garantir uma boa performance nas jobs.

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
	IdTipoAcordo smallint,
	IdDevedor int,
	IdTitulo int,
	Plano int,
	NumeroParcela int,
	Valor money,
	IdNegociadorResponsavel int,
	DataInclusao datetime,
	Proposta char(1),
	DataAprovacaoProposta datetime,
	IdStatusAcordo int,
	DataCancelamento datetime,
	IdOrigemAcordo char(2)
);

--- | Usuarios

If Object_id('Tempdb..#Usuarios') Is not null Drop table #Usuarios;
Create table #Usuarios (
	IdUsuario int,
	Referencia varchar(32)
);

--- | Acordos final

If Object_id('Tempdb..#AcordosFinal') Is not null Drop table #AcordosFinal;
Create table #AcordosFinal (
	IdBase int,
	Data datetime,
	IdDevedor int,
	IdTitulo int,
	Plano smallint,
	NumeroParcela smallint,
	Valor money,
	IdAcordo int,
	IdTipoAcordo smallint,
	DataInclusao datetime,
	Proposta char(1),
	DataAprovacaoProposta datetime,
	IdStatusAcordo int,
	DataCancelamento datetime,
	IdOrigemAcordo char(2),
	Referencia varchar(32)
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

--- | Acordos

Insert into #Acordos (
					  IdAcordo,
					  IdTipoAcordo,
					  IdDevedor,
					  IdTitulo,
					  Plano,
					  NumeroParcela,
					  Valor,
					  IdNegociadorResponsavel,
					  DataInclusao,
					  Proposta,
					  DataAprovacaoProposta,
					  IdStatusAcordo,
					  DataCancelamento,
					  IdOrigemAcordo
					 )
Select
	*
From openquery (misitau,'
Select distinct
	a.IdAcordo,
	a.IdTipoAcordo,
	a.IdDevedor,
	b.IdTitulo,
	a.Plano,
	c.NumeroParcela,
	c.Valor,
	a.IdNegociadorResponsavel,
	a.DataInclusao,
	a.Proposta,
	a.DataAprovacaoProposta,
	a.IdStatusAcordo,
	a.DataCancelamento,
	d.IdOrigemAcordo
From misitau.dbo.Acordos a With(nolock)
inner join misitau.dbo.AcordosParcelasNegociadas b With(nolock) on a.IdAcordo = b.IdAcordo
inner join misitau.dbo.AcordosParcelasPagar c With(nolock) on a.IdAcordo = c.IdAcordo
Left join misitau.dbo.OrigemAcordos d With(nolock) on a.IdAcordo = d.IdAcordo
Where
	a.DataInclusao >= Convert(date,Dateadd(hour,-3,Getdate())) 
	or a.DataCancelamento >= Convert(date,Dateadd(hour,-3,Getdate()))
	or a.DataAprovacaoProposta >= Convert(date, Dateadd(hour,-3,Getdate()));');

--- Usuarios
	
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

--- | Acordos final

Insert into #AcordosFinal (
						IdBase,
						Data,
						IdDevedor,
						IdTitulo,
						Plano,
						NumeroParcela,
						Valor,
						IdAcordo,
						IdTipoAcordo,
						DataInclusao,
						Proposta,
						DataAprovacaoProposta,
						IdStatusAcordo,
						DataCancelamento,
						IdOrigemAcordo,
						Referencia
						)
Select
	b.IdBase,
	b.Data,
	b.IdDevedor,
	b.IdTitulo,
	a.Plano,
	a.NumeroParcela,
	a.Valor,
	a.IdAcordo,
	a.IdTipoAcordo,
	a.DataInclusao,
	a.Proposta,
	a.DataAprovacaoProposta,
	a.IdStatusAcordo,
	a.DataCancelamento,
	a.IdOrigemAcordo,
	c.Referencia
From #Acordos a With(nolock)
Inner join #Base b With(nolock) on a.IdDevedor = b.IdDevedor
								   and a.IdTitulo = b.IdTitulo
Inner join #Usuarios c With(nolock) on a.IdNegociadorResponsavel = c.IdUsuario

Set @LinhasOrigem = @@RowCount;

------------------------------> Criacao de índices

Set @Etapa = 'Criacao de indices';

/* Cria index não clusterizado */
Create nonclustered index IxAcordos360 on #AcordosFinal (IdBase, IdAcordo, IdDevedor, IdTitulo, NumeroParcela);

------------------------------> Persistencia final

Set @Etapa = 'Persistencia final';

--- | Tabela fisica

Insert into dbDataDwItau.itau.Acordos360 (
										  IdBase,
										  Data,
										  IdDevedor,
										  IdTitulo,
										  Plano,
										  NumeroParcela,
										  Valor,
										  IdAcordo,
										  IdTipoAcordo,
										  DataInclusao,
										  Proposta,
										  DataAprovacaoProposta,
										  IdStatusAcordo,
										  DataCancelamento,
										  IdOrigemAcordo,
										  Referencia
										 )
Select 
	IdBase,
	Data,
	IdDevedor,
	IdTitulo,
	Plano,
	NumeroParcela,
	Valor,
	IdAcordo,
	IdTipoAcordo,
	DataInclusao,
	Proposta,
	DataAprovacaoProposta,
	IdStatusAcordo,
	DataCancelamento,
	IdOrigemAcordo,
	Referencia
From
	#AcordosFinal a
Where 
	Not exists (Select 1
				From dbDataDwItau.itau.Acordos360 b
				Where 
					a.IdBase = b.IdBase
					and a.IdAcordo = b.IdAcordo
					and a.IdDevedor = b.IdTitulo
					and a.NumeroParcela = b.NumeroParcela
					and a.Data = b.Data)

Set @LinhasInseridas = @@RowCount;

------------------------------> Atualizacao de dados

Set @Etapa = 'Atualizacao de dados';

--- | Atualiza campos da tabela fisica

/* Atualiza a Proposta e Cancelamento */

Update a
Set a.Proposta = b.Proposta,
	a.DataAprovacaoProposta = b.DataAprovacaoProposta,
	a.DataCancelamento = b.DataCancelamento
From dbDataDwItau.itau.Acordos360 a With(nolock)
Inner join #AcordosFinal b With(nolock) on a.IdAcordo = b.IdAcordo
										 and a.IdDevedor = b.IdDevedor
										 and a.Data = b.Data
Where
	Isnull(a.DataAprovacaoProposta,'1900-01-01') <> Isnull(b.DataAprovacaoProposta,'1900-01-01')
	or a.IdStatusAcordo <> b.IdStatusAcordo
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