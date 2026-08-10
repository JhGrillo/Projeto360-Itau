Create or alter procedure itau.ProcVencimentos360 as 

------------------------------> Descrição da procedure

/*
	Padrão de escrita: PascalCase
	Nome: ProcVencimentos360
	DataCriação: 10/08/2026
	Criado por: Leonardo Matheus Talarico
	DataAtualização: 
	Atualizado por: 

	Descrição atualização: (Data, Atualizado por, Descrição, git)

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
	IdDevedor int,
	IdNegociadorResponsavel int,
	IdTitulo int,
	IdAcordo int,
	NumeroParcela int,
	Valor money,
	DataCancelamento datetime
);

--- | Origem acordos

If Object_id('Tempdb..#OrigemAcordos') Is not null Drop table #OrigemAcordos;
Create table #OrigemAcordos (
	IdAcordo int,
	IdOrigemAcordo char(1)
);

--- | Usuários

If Object_id('Tempdb..#Usuarios') Is not null Drop table #Usuarios;
Create table #Usuarios (
	IdUsuario int,
	Referencia varchar(32)
);

--- | Vencimentos final

If Object_id('Tempdb..#VencimentosFinal') Is not null Drop table #VencimentosFinal;
Create table #VencimentosFinal (
	IdBase int,
	Data datetime,
	IdDevedor int,
	IdTitulo int,
	IdAcordo int,
	NumeroParcela int,
	Valor money,
	Referencia varchar(32),
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
	Data Between Convert(date, Getdate()) and Getdate()

--- | Vencimentos

Insert into #Vencimentos (
						  IdDevedor,
						  IdNegociadorResponsavel,
						  IdTitulo,
						  IdAcordo,
						  NumeroParcela,
						  Valor,
						  DataCancelamento
						  )
Select
	*
From Openquery (misitau,'
Select distinct
	b.IdDevedor,
	b.IdNegociadorResponsavel,
	c.IdTitulo,
	b.IdAcordo,
	a.NumeroParcela,
	a.Valor,
	b.DataCancelamento
From misitau.dbo.AcordosParcelasPagar a With(nolock)
Inner join misitau.dbo.Acordos b With(nolock) on a.IdAcordo = b.IdAcordo
Inner join misitau.dbo.AcordosParcelasNegociadas c With(nolock) on a.IdAcordo =c.IdAcordo
Where
	DataVencimento = convert(date, Getdate())
	or Convert(date,b.DataCancelamento) = convert(date, Getdate());');

--- | Origem Acordos

Insert into #OrigemAcordos (
							IdAcordo,
							IdOrigemAcordo
						    )
Select
	*
From openquery (misitau,'
Select
	IdAcordo,
	IdOrigemAcordo
From
	misitau.dbo.OrigemAcordos With(nolock);');

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
From
	misitau.dbo.Usuarios With(nolock);');

--- | Vencimentos Final

Insert into #VencimentosFinal (
							  Data,
							  IdDevedor,
							  IdTitulo,
							  IdAcordo,
							  NumeroParcela,
							  Valor,
							  Referencia,
							  DataCancelamento,
							  IdOrigemAcordo
							  )
Select
	a.Data,
	a.IdDevedor,
	a.IdTitulo,
	b.IdAcordo,
	b.NumeroParcela,
	b.Valor,
	c.Referencia,
	b.DataCancelamento,
	d.IdOrigemAcordo
From #Base a
inner join #Vencimentos b on a.IdDevedor = b.IdDevedor
							 and a.IdTitulo = b.IdTitulo
inner join #Usuarios c on b.IdNegociadorResponsavel = c.IdUsuario
inner join #OrigemAcordos d on b.IdAcordo = d.IdAcordo

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
											  IdDevedor,
											  IdTitulo,
											  IdAcordo,
											  NumeroParcela,
											  Valor,
											  Referencia,
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
	Valor,
	Referencia,
	DataCancelamento,
	IdOrigemAcordo
From #VencimentosFinal a
Where
	not exists (
				Select 1
				From dbDataDwItau.itau.Vencimentos360 b With(nolock)
				Where 
					a.IdBase = b.IdBase
					and a.IdDevedor = b.IdDevedor
					and a.IdTitulo = b.IdTitulo
					and a.IdAcordo = b.IdAcordo
					and a.Data = b.Data)

Set @LinhasInseridas = @@RowCount;
Set @LinhasTotaisDestino = @LinhasInseridas;
Set @DataHoraFim = Dateadd(hour,-3,Getdate());
	
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
