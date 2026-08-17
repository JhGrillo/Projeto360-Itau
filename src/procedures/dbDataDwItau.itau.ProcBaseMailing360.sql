Create or Alter procedure itau.ProcBaseMailing360 as

----------------------------> Descrição da procedure

/*
    Padrão de escrita: PascalCase
    Nome: ProcBaseMailing360
    DataCriação: 12/08/2026
    Criado por: João Henrique Cavalheiro Grillo
    DataAtualização: 17/08/2026
    Atualizado por:	João Henrique Cavalheiro Grillo

    Descrição atualização: (Data, Atualizado por, Descrição, git)

	17/08/2026 João Henrique Cavalheiro Grillo: Refatoramento da procedure para melhoria do tempo de execução, foi criado index nas origens do mailing e na Base360
	oque melhorou significativamente o tempo de execução.
*/

----------------------------> Definições de variaveis e controles de ambiente

Set Nocount On;

Declare @NomeProcedure varchar(128) = 'ProcBaseMailing360',
        @Etapa varchar(100) = 'Inicio',
		@UltimaAtualizacao datetime,
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
Exec dbDataDwItau.log.ProcControles
    @TipoLog = 'Execucao',
    @NomeProcedure = @NomeProcedure,
    @DataHoraInicio = @DataHoraInicio,
    @StatusExecucao = 'Executando',
    @IdExecucao = @IdExecucao OUTPUT;

Begin Try

------------------------------> Criação de tabelas

Set @Etapa = 'Criacao das tabelas temporarias';

--- | Base

If Object_id('Tempdb..#Base') Is not null Drop table #Base;
Create table #Base (
	IdBase int,
	Data datetime,
	CodigoReferencia smallint,
	IdDevedor int,
	IdTitulo int
);

--- | Mailing

If Object_id('Tempdb..#Mailing') Is not null Drop table #Mailing;
Create table #Mailing (
	IdDevedor int,
	IdCarteira int,
	CodigoReferencia smallint,
	IdRetirada int
);

--- | MailingFinal

If Object_id('Tempdb..#MailingFinal') Is not null Drop table #MailingFinal;
Create table #MailingFinal (
	IdBase int,
	Data datetime,
	IdDevedor int,
	IdTitulo int,
	IdRetirada int
);

------------------------------> Insere dados em tabelas

--- | Base

Insert into #Base (
					IdBase,
					Data,
					CodigoReferencia,
					IdDevedor,
					IdTitulo
				)
Select
	IdBase,
	Data,
	CodigoReferencia,
	IdDevedor,
	IdTitulo
From dbDataDwItau.itau.Base360 With(nolock)
Where
	Data >= Convert(date,Getdate());

/*
	Criação de index não clusterizado
	Obs: Feito fora de etapa pois favorece no carregamento de dados na tabela final
*/

Create nonclustered index IxBase on #Base (IdDevedor, CodigoReferencia) Include (Data, IdTitulo);

--- | Mailing

Insert into #Mailing (
					IdDevedor,
					IdCarteira,
					CodigoReferencia,
					IdRetirada
					)
Select
	a.IdDevedor,
	a.IdCarteira,
	b.CodigoReferencia,
	a.IdRetirada
From misitau.misitau.dbo.Mailing a With(nolock)
Inner join misitau.misitau.dbo.Carteiras b With(nolock) on a.IdCarteira = b.IdCarteira;

Set @LinhasOrigem += @@RowCount;

/*
	Criação de index não clusterizado
	Obs: Feito fora de etapa pois favorece no carregamento de dados na tabela final
*/

Create nonclustered index IxMailing on #Mailing (IdDevedor, CodigoReferencia) Include (IdRetirada);

--- | Mailing final

Insert into #MailingFinal (
							IdBase,
							Data,
							IdDevedor,
							IdTitulo,
							IdRetirada
						)
Select
	b.IdBase,
	b.Data,
	a.IdDevedor,
	b.IdTitulo,
	a.IdRetirada
From #Mailing a
Inner join #Base b on a.IdDevedor = b.IdDevedor
				      and a.CodigoReferencia = b.CodigoReferencia;

/*
	Criação de index não clusterizado
	Obs: Feito fora de etapa pois favorece no carregamento de dados na tabela final
*/

Create nonclustered index IxMailingFinal on #MailingFinal (IdBase) Include (Data, IdDevedor, IdTitulo, IdRetirada);

------------------------------> Persistencia final

Set @Etapa = 'Persistencia final';

--- | Tabela fisica

Insert into dbDataDwItau.itau.BaseMailing360 (
											IdBase,
											Data,
											IdDevedor,
											IdTitulo,
											IdRetirada
											)
Select
	IdBase,
	Data,
	IdDevedor,
	IdTitulo,
	IdRetirada
From #MailingFinal a
Where
	Not exists (Select 1
				From dbDataDwItau.itau.BaseMailing360 b With(nolock)
				Where
					a.IdBase = b.IdBase);

Set @LinhasInseridas = @@RowCount;

------------------------------> Atualizacao de dados

Set @Etapa = 'Atualizacao de dados';

--- | Atualiza campos da tabela fisica

Update a
Set a.IdRetirada = b.IdRetirada
From dbDataDwItau.itau.BaseMailing360 a With(nolock)
Inner join #MailingFinal b With(nolock) on a.IdBase = b.IdBase
Where
	Isnull(a.IdRetirada,0) <> Isnull(b.IdRetirada,0);

Set @LinhasAtualizadas += @@RowCount;
Set @LinhasTotaisDestino = @LinhasInseridas + isnull(@LinhasAtualizadas, 0);
Set @DataHoraFim = Getdate();

/* Grava volumetria controles de log */
Exec dbDataDwItau.log.ProcControles
    @TipoLog = 'Volumetria',
    @IdExecucao = @IdExecucao,
    @NomeTabelaOrigem = 'misitau.dbo.Mailing',
    @NomeTabelaDestino = 'dbDataDWItau.itau.BaseMailing360',
    @LinhasOrigem = @LinhasOrigem,
    @LinhasInseridas = @LinhasInseridas,
    @LinhasTotaisDestino = @LinhasTotaisDestino;

/* Finaliza execução controles de log concluido */
Exec dbDataDwItau.[log].ProcControles
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