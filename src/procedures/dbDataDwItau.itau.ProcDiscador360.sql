Create or Alter procedure itau.ProcDiscador360 as

----------------------------> Descrição da procedure

/*
    Padrão de escrita: PascalCase
    Nome: ProcDiscador360
    DataCriação: 07/08/2026
    Criado por: João Henrique Cavalheiro Grillo
    DataAtualização:
    Atualizado por:

    Descrição atualização: (Data, Atualizado por, Descrição, git)
*/

----------------------------> Definições de variaveis e controles de ambiente

Set Nocount On;

Declare @NomeProcedure varchar(128) = 'ProcDiscador360',
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

--- | Discador

If Object_id('Tempdb..#Discador') Is not null Drop table #Discador;
Create table #Discador (
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
	TipoTelefone varchar(32),
	DuracaoChamada int,
	DuracaoFalado int,
	DuracaoTabulando int,
	Chave varchar(256)
);

--- | Discador final

If Object_id('Tempdb..#DiscadorFinal') Is not null Drop table #DiscadorFinal;
Create table #DiscadorFinal (
	IdBase int,
	Data datetime,
	IdDevedor int,
	IdTitulo int,
	DDD char(2),
	Numero char(9),
	Origem varchar(20),
	Classificacao varchar(32),
	MotivoFinalizacao varchar(256),
	Referencia varchar(32),
	Campanha varchar(56),
	TipoTelefone varchar(32),
	DuracaoChamada float,
	DuracaoFalado float,
	DuracaoTabulando float,
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

--- | Discador

Insert into #Discador (
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
				TipoTelefone,
				DuracaoChamada,
				DuracaoFalado,
				DuracaoTabulando,
				Chave
					)
Select
	*
From OpenQuery([srv-mis],'
Select
	Inicio_discagem,
	Cliente,
	Cpf_cnpj,
	Contrato,
	Left(Telefone_discado,2) as DDD,
	Right(Telefone_discado,9) as Numero,
	Origem,
	Classificacao,
	Motivo_finalizacao,
	Cobrador,
	Campanha,
	Tipo_telefone,
	Duracao_chamada,
	Duracao_conectado,
	Duracao_wrap_up,
	Itr_key
From dbDataStoreHouse.geral.CallDialer With(nolock)
Where
	Inicio_discagem >= Convert(date,Getdate())
	and Cliente in (771,777,779,799);');

Set @LinhasOrigem = @@RowCount;

--- | Discador final

Insert into #DiscadorFinal (
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
						TipoTelefone,
						DuracaoChamada,
						DuracaoFalado,
						DuracaoTabulando,
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
	a.TipoTelefone,
	Convert(float,a.DuracaoChamada) / 86400 as DuracaoChamada,
	Convert(float,a.DuracaoFalado) / 86400 as DuracaoFalado,
	Convert(float,a.DuracaoTabulando) / 86400 as DuracaoTabulando,
	a.Chave
From #Discador a
Inner join #Base b on a.CodigoReferencia = b.CodigoReferencia
					  and a.CnpjCpf = b.CnpjCpf;

------------------------------> Persistencia final

Set @Etapa = 'Persistencia final';

--- | Tabela fisica

Insert into dbDataDwItau.itau.Discador360 (
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
										TipoTelefone,
										DuracaoChamada,
										DuracaoFalado,
										DuracaoTabulando,
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
	TipoTelefone,
	DuracaoChamada,
	DuracaoFalado,
	DuracaoTabulando,
	Chave
From #DiscadorFinal a
Where
	Not exists (Select 1
				From dbDataDwItau.itau.Discador360 b With(nolock)
				Where
					a.IdDevedor = b.IdDevedor
					and a.IdTitulo = b.IdTitulo
					and a.Data = b.Data);

Set @LinhasInseridas = @@RowCount;
Set @LinhasTotaisDestino = @LinhasInseridas;
Set @DataHoraFim = Getdate();

/* Grava volumetria controles de log */
Exec dbDataDwItau.log.ProcControles
    @TipoLog = 'Volumetria',
    @IdExecucao = @IdExecucao,
    @NomeTabelaOrigem = 'dbDataStoreHouse.geral.CallDialer',
    @NomeTabelaDestino = 'dbDataDWItau.itau.Discador360',
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