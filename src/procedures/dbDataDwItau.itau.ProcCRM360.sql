Create or Alter procedure itau.ProcCRM360 as

----------------------------> Descrição da procedure

/*
    Padrão de escrita: PascalCase
    Nome: ProcCRM360
    DataCriação: 07/08/2026
    Criado por: João Henrique Cavalheiro Grillo
    DataAtualização: 13/08/2026
    Atualizado por: João Henrique Cavalheiro Grillo

    Descrição atualização: (Data, Atualizado por, Descrição, git)
	13/08/2026 João Henrique Cavalheiro Grillo: Incluido na tabela as marcações de Atendimento, CPC e Acordo.
*/

----------------------------> Definições de variaveis e controles de ambiente

Set Nocount On;

Declare @NomeProcedure varchar(128) = 'ProcCRM360',
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
	IdDevedor int,
	IdTitulo int
);

--- | CRM

If Object_id('Tempdb..#CRM') Is not null Drop table #CRM;
Create table #CRM (
	Data datetime,
	IdDevedor int,
	IdTitulo int,
	CodigoOcorrencia varchar(32),
	TipoOcorrencia varchar(64),
	IdLigacao int,
	IdOrigemLigacao char(2),
	DDD char(2),
	Numero char(9),
	Chave varchar(256),
	IdAcordo int,
	Referencia varchar(64),
	IdOrigem int,
	IdClassificacao tinyint
);

--- | CRMFinal

If Object_id('Tempdb..#CRMFinal') Is not null Drop table #CRMFinal;
Create table #CRMFinal (
	IdBase int,
	Data datetime,
	IdDevedor int,
	IdTitulo int,
	CodigoOcorrencia varchar(32),
	TipoOcorrencia varchar(64),
	IdLigacao int,
	IdOrigemLigacao char(2),
	DDD char(2),
	Numero char(9),
	Chave varchar(256),
	IdAcordo int,
	Referencia varchar(64),
	Atendimento int,
	CPC int,
	Acordo int
);

------------------------------> Insere dados em tabelas

--- | Base

Insert into #Base
Select
	IdBase,
	Data,
	IdDevedor,
	IdTitulo
From itau.Base360 With(nolock)
Where
	Data >= Convert(date,Getdate());

--- | CRM

/* Ocorrências */
Insert into #CRM (
					Data,
					IdDevedor,
					IdTitulo,
					CodigoOcorrencia,
					TipoOcorrencia,
					IdLigacao,
					IdOrigemLigacao,
					DDD,
					Numero,
					Chave,
					IdAcordo,
					Referencia,
					IdOrigem,
					IdClassificacao
					)
Select
	a.DataOcorrencia,
	a.IdDevedor,
	a.IdTitulo,
	b.CodigoOcorrencia,
	b.TipoOcorrencia,
	c.IdLigacao,
	c.IdOrigemLigacao,
	c.DDDLigacao,
	c.NumeroLigacao,
	c.Chave,
	a.IdAcordo,
	d.Referencia,
	a.IdOrigem,
	b.IdClassificacao
From misitau.misitau.dbo.Ocorrencias a With(nolock)
Inner join misitau.misitau.dbo.TiposOcorrencias b With(nolock) on a.IdTipoOcorrencia = b.IdTipoOcorrencia
Left join misitau.misitau.dbo.Ligacoes c With(nolock) on a.IdLigacao = c.IdLigacao
Left join misitau.misitau.dbo.Usuarios d With(nolock) on a.IdUsuarioInclusao = d.IdUsuario
Where
	a.DataOcorrencia >= Convert(date,Getdate());

Set @LinhasOrigem = @@RowCount;

/* Eventos */
Insert into #CRM (
				Data,
				IdDevedor,
				IdTitulo,
				CodigoOcorrencia,
				TipoOcorrencia,
				IdLigacao,
				IdOrigemLigacao,
				DDD,
				Numero,
				Chave,
				Referencia,
				IdOrigem,
				IdClassificacao
				)
Select
	a.DataEvento,
	a.IdDevedor,
	a.IdTitulo,
	b.CodigoEvento,
	b.TipoEvento,
	c.IdLigacao,
	c.IdOrigemLigacao,
	c.DDDLigacao,
	c.NumeroLigacao,
	c.Chave,
	d.Referencia,
	a.IdOrigem,
	b.IdClassificacao
From misitau.misitau.dbo.Eventos a With(nolock)
Inner join misitau.misitau.dbo.TiposEventos b With(nolock) on a.IdTipoEvento = b.IdTipoEvento
Left join misitau.misitau.dbo.Ligacoes c With(nolock) on a.IdLigacao = c.IdLigacao
Left join misitau.misitau.dbo.Usuarios d With(nolock) on a.IdUsuarioInclusao = d.IdUsuario
Where
	a.DataEvento >= Convert(date,Getdate());

Set @LinhasOrigem += @@RowCount;

--- | CRM final

Insert into #CRMFinal (
					IdBase,
					Data,
					IdDevedor,
					IdTitulo,
					CodigoOcorrencia,
					TipoOcorrencia,
					IdLigacao,
					IdOrigemLigacao,
					DDD,
					Numero,
					Chave,
					IdAcordo,
					Referencia,
					Atendimento,
					CPC,
					Acordo
					)
Select
	b.IdBase,
	a.Data,
	a.IdDevedor,
	a.IdTitulo,
	a.CodigoOcorrencia,
	a.TipoOcorrencia,
	a.IdLigacao,
	a.IdOrigemLigacao,
	a.DDD,
	a.Numero,
	a.Chave,
	a.IdAcordo,
	a.Referencia,
	Case when a.IdOrigem not in (1,5) or a.IdAcordo is not null then 1 end as Atendimento,
	Case when a.IdClassificacao = 1 then 1 end as CPC,
	Case when a.IdAcordo is not null then 1 end as Acordo
From #CRM a
Inner join #Base b on a.IdDevedor = b.IdDevedor
				      and a.IdTitulo = b.IdTitulo
					  and Convert(date,a.Data) = b.Data;

------------------------------> Persistencia final

Set @Etapa = 'Persistencia final';

--- | Tabela fisica

Insert into dbDataDwItau.itau.CRM360 (
									IdBase,
									Data,
									IdDevedor,
									IdTitulo,
									CodigoOcorrencia,
									TipoOcorrencia,
									IdLigacao,
									IdOrigemLigacao,
									DDD,
									Numero,
									Chave,
									IdAcordo,
									Referencia,
									Atendimento,
									CPC,
									Acordo
									)
Select
	IdBase,
	Data,
	IdDevedor,
	IdTitulo,
	CodigoOcorrencia,
	TipoOcorrencia,
	IdLigacao,
	IdOrigemLigacao,
	DDD,
	Numero,
	Chave,
	IdAcordo,
	Referencia,
	Atendimento,
	CPC,
	Acordo
From #CRMFinal a
Where
	Not exists (Select 1
				From dbDataDwItau.itau.CRM360 b With(nolock)
				Where
					a.IdBase = b.IdBase
					and a.Data = b.Data);

Set @LinhasInseridas = @@RowCount;
Set @LinhasTotaisDestino = @LinhasInseridas;
Set @DataHoraFim = Getdate();

/* Grava volumetria controles de log */
Exec dbDataDwItau.log.ProcControles
    @TipoLog = 'Volumetria',
    @IdExecucao = @IdExecucao,
    @NomeTabelaOrigem = 'misitau.dbo.Ocorrencias + misitau.dbo.Eventos',
    @NomeTabelaDestino = 'dbDataDWItau.itau.CRM360',
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