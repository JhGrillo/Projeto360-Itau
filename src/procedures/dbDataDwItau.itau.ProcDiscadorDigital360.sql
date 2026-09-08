Create or Alter Procedure itau.ProcDiscadorDigital360 as 

----------------------------> Descrição da procedure

/*
    Padrão de escrita: PascalCase
    Nome: ProcDiscadorDigital360
    DataCriação: 07/08/2026
    Criado por: João Henrique Cavalheiro Grillo
    DataAtualização:
    Atualizado por:

    Descrição atualização: (Data, Atualizado por, Descrição, git)

	31/08/2026 Leonardo Matheus Talarico: Foi alterado a forma como as linhas origens são contabilizadas. Agora ela é contabilizada no momento em que
	as informações de base e discagens são cruzadas e consideramos apenas as linhas que ainda não estão na tabela de destino final

*/

----------------------------> Definições de variaveis e controles de ambiente

Set Nocount On;

Declare @NomeProcedure varchar(128) = 'ProcDiscadorDigital360',
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
	CnpjCpf varchar(14),
	IdTitulo int,
	NumeroContrato varchar(32)
);

--- | Discador digital

If Object_id('Tempdb..#DiscadorDigital') Is not null Drop table #DiscadorDigital;
Create table #DiscadorDigital (
	Data datetime,
	CodigoReferencia smallint,
	CnpjCpf varchar(14),
	NumeroContrato varchar(20),
	DDD char(2),
	Numero char(9),
	Origem varchar(20),
	Classificacao varchar(32),
	MotivoFinalizacao varchar(256),
	Referencia varchar(32),
	Campanha varchar(56),
	DuracaoChamada int,
	Chave varchar(256)
);

--- | Discador final

If Object_id('Tempdb..#DiscadorDigitalFinal') Is not null Drop table #DiscadorDigitalFinal;
Create table #DiscadorDigitalFinal (
	IdBase int,
	Data datetime,
	CodigoReferencia smallint,
	IdDevedor int,
	IdTitulo int,
	DDD char(2),
	Numero char(9),
	Origem varchar(20),
	Classificacao varchar(32),
	MotivoFinalizacao varchar(256),
	Referencia varchar(32),
	Campanha varchar(56),
	DuracaoChamada int,
	Chave varchar(256)
);

------------------------------> Insere dados em tabelas

--- | Base

Insert into #Base
Select
	IdBase,
	Data,
	CodigoReferencia,
	IdDevedor,
	CnpjCpf,
	IdTitulo,
	NumeroContrato
From itau.Base360 With(nolock)
Where
	Data >= Convert(date,Getdate());

--- | Discador digital

Insert into #DiscadorDigital (
				Data,
				CodigoReferencia,
				CnpjCpf,
				NumeroContrato,
				DDD,
				Numero,
				Origem,
				Classificacao,
				MotivoFinalizacao,
				Referencia,
				Campanha,
				DuracaoChamada,
				Chave
					)
Select
	*
From OpenQuery([srv-mis],'
Select
	Data,
	Cliente,
	Right(''0000000'' + CpfCnpj,14),
	Contrato,
	Left(TelefoneDiscado,2) as DDD,
	Right(TelefoneDiscado,9) as Numero,
	Origem,
	Classificacao,
	Case
		when Tabulacao = '''' then null
		else Tabulacao
	end as MotivoFinalizacao,
	Case
		when Cobrador = '''' then null
		else Cobrador
	end as Referencia,
	Campanha,
	DuracaoChamada,
	CallId
From dbDataDigital.digital.CallDataAD With(nolock)
Where
	Data >= Convert(date,Getdate())
	and Cliente in (771,777,779,799);');

--- | Discador digital final

Insert into #DiscadorDigitalFinal (
								IdBase,
								Data,
								IdDevedor,
								IdTitulo,
								DDD,
								Numero,
								Origem,
								Classificacao,
								MotivoFinalizacao,
								Referencia,
								Campanha,
								DuracaoChamada,
								Chave
								)
Select
	b.IdBase,
	a.Data,
	b.IdDevedor,
	b.IdTitulo,
	a.DDD,
	a.Numero,
	a.Origem,
	a.Classificacao,
	a.MotivoFinalizacao,
	a.Referencia,
	a.Campanha,
	Convert(float,a.DuracaoChamada) / 86400 as DuracaoChamada,
	Chave
From #DiscadorDigital a
Inner join #Base b on a.CodigoReferencia = b.CodigoReferencia
					  and a.CnpjCpf = b.CnpjCpf
Where
	Not exists (Select 1
				From
					dbDataDwItau.itau.DiscadorDigital360 c With(nolock)
				Where
					b.IdDevedor = c.IdDevedor
					and b.IdTitulo = c.IdTitulo
					and a.Data = c.Data);

Set @LinhasOrigem = @@RowCount;

------------------------------> Persistencia final

Set @Etapa = 'Persistencia final';

--- | Tabela fisica

Insert into dbDataDwItau.itau.DiscadorDigital360 (
												IdBase,
												Data,
												IdDevedor,
												IdTitulo,
												DDD,
												Numero,
												Origem,
												Classificacao,
												MotivoFinalizacao,
												Referencia,
												Campanha,
												DuracaoChamada,
												Chave
												)
Select
	IdBase,
	Data,
	IdDevedor,
	IdTitulo,
	DDD,
	Numero,
	Origem,
	Classificacao,
	MotivoFinalizacao,
	Referencia,
	Campanha,
	DuracaoChamada,
	Chave
From #DiscadorDigitalFinal a
Where
	Not exists (Select 1
				From dbDataDwItau.itau.DiscadorDigital360 b With(nolock)
				Where
					a.IdDevedor = b.IdDevedor
					and a.IdTitulo = b.IdTitulo
					and a.Data = b.Data);

Set @LinhasInseridas = @@RowCount;
Set @LinhasTotaisDestino = Isnull(@LinhasInseridas, 0);
Set @DataHoraFim = Getdate();

/* Grava volumetria controles de log */
Exec dbDataDwItau.log.ProcControles
    @TipoLog = 'Volumetria',
    @IdExecucao = @IdExecucao,
    @NomeTabelaOrigem = 'dbDataDigital.digital.CallDataAD',
    @NomeTabelaDestino = 'dbDataDWItau.itau.DiscadorDigital360',
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