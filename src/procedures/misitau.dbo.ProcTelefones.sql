Create or alter procedure dbo.ProcTelefones as 

------------------------------> Descrição da procedure

/*
	Padrão de escrita: PascalCase
	Nome: ProcAcordos
	DataCriação: 27/07/2026
	Criado por: Leonardo Matheus Talarico
	DataAtualização:
	Atualizado por:

	Descrição atualização: (Data, Atualizado por, Descrição, git)
*/

------------------------------> Definições de variaveis e controles de ambiente

Set Nocount On;

Declare @NomeProcedure varchar(128) = 'ProcAcordos',
        @Etapa varchar(100) = 'Inicio',
		@UltimaAtualizacao datetime,
		@DataPagamento datetime,
        @IdExecucao int,
        @LinhasOrigem int,
        @LinhasInseridas int,
        @LinhasAtualizadas int,
        @LinhasTotaisDestino int,
        @DataHoraInicio datetime = Dateadd(hour,-3,Getdate()),
        @DataHoraFim datetime,
        @MensagemErro varchar(max),
        @NumeroErro int,
        @LinhaErro int;


/* Inicia o controle de logs */
Exec misitau.[log].ProcControles
    @TipoLog = 'Execucao',
    @NomeProcedure = @NomeProcedure,
    @DataHoraInicio = @DataHoraInicio,
    @StatusExecucao = 'Executando',
    @IdExecucao = @IdExecucao OUTPUT;

Begin Try

--------------------------------> Criacao de tabelas temporarias

Set @Etapa = 'Criacao das tabelas temporarias';

--- | Telefones

If Object_id('Tempdb..#Telefones') Is not null Drop table #Telefones;
Create table #Telefones (

	IdTelefone int,
	IdDevedor int,
	IdOrigem int,
	IdQualificacao int,
	IdPropriedade int,
	DDD char(2),
	Numero char(9),
	Pontuacao decimal,
	DataInclusao datetime,
	DataAtualizacao datetime,
	IdTipoTelefone tinyint,
	WhatsApp char(1),
	CPC char(1),
	DataUltimoCPC datetime,
	IdEnriquecimento int,
	IdFornecedor int
);

------------------------------> Carga das tabelas temporarias

Set @Etapa = 'Carga das tabelas temporarias';

--- | Insere telefones na tabela

Set @IdTelefone = (Select Max(IdTelefone) From misitau.dbo.Telefones With(nolock));

Set @UltimaAtualizacao = (Select 
                            Case
                                when Datepart(hour,Max(DataHoraInicio)) >= 22 then Max(Dateadd(day,+1,Convert(date,DataHoraInicio)))
                                else Max(Convert(date,DataHoraInicio))
                            end
                          From misitau.[log].ControleExecucoes
                          Where
                            NomeProcedure = 'ProcTelefones'
                            and StatusExecucao = 'Concluida');

Insert into #Telefones (
						IdTelefone,
						IdDevedor,
						IdOrigem,
						IdQualificacao,
						IdPropriedade,
						DDD,
						Numero,
						Pontuacao,
						DataInclusao,
						DataAtualizacao,
						IdTipoTelefone,
						WhatsApp,
						CPC,
						DataUltimoCPC,
						IdEnriquecimento,
						IdFornecedor
						)
Select
	IdTelefone,
	IdDevedor,
	IdOrigem,
	IdQualificacao,
	IdPropriedade,
	DDD,
	Numero,
	Pontuacao,
	DataInclusao,
	DataAtualizacao,
	IdTipoTelefone,
	WhatsApp,
	CPC,
	DataUltimoCPC,
	IdEnriquecimento,
	IdFornecedor
From
	misitau.cob.Telefones a
Where
	(IdTelefone >= isnull(@IdTelefone, 0)
	or DataAtualizacao >= @UltimaAtualizacao)
	and not exists (Select 1
					From misitau.dbo.Telefones b
					Where a.IdTelefone = b.IdTelefone
					and Isnull(a.DataAtualizacao,'1900-01-01') = Isnull(b.DataAtualizacao,'1900-01-01'));

Set @LinhasOrigem = @@RowCount;

------------------------------> Criacao de índices

Set @Etapa = 'Criacao de indices';

/* Cria index não clusterizado */
Create nonclustered index IxTelefones on #Telefones (IdTelefone);


------------------------------> Persistencia final

Set @Etapa = 'Persistencia final';

--- | Tabela fisica

Insert into misitau.dbo.Telefones (
								   IdTelefone,
								   IdDevedor,
								   IdOrigem,
								   IdQualificacao,
								   IdPropriedade,
								   DDD,
								   Numero,
								   Pontuacao,
								   DataInclusao,
								   DataAtualizacao,
								   IdTipoTelefone,
								   WhatsApp,
								   CPC,
								   DataUltimoCPC,
								   IdEnriquecimento,
								   IdFornecedor
								   )
Select
	IdTelefone,
	IdDevedor,
	IdOrigem,
	IdQualificacao,
	IdPropriedade,
	DDD,
	Numero,
	Pontuacao,
	DataInclusao,
	DataAtualizacao,
	IdTipoTelefone,
	WhatsApp,
	CPC,
	DataUltimoCPC,
	IdEnriquecimento,
	IdFornecedor
From
	#Telefones a
Where
	not exists (Select 1
				From 
					misitau.dbo.Telefones b
				Where 
					a.IdTelefone = b.IdTelefone);

Set @LinhasInseridas = @@RowCount;

------------------------------> Atualizacao de dados

Set @Etapa = 'Atualizacao de dados';

--- | Atualiza campos da tabela fisica

Update a
Set a.DataAtualizacao = b.DataAtualizacao,
	a.Whatsapp = b.Whatsapp,
	a.Cpc = b.Cpc,
	a.DataUltimoCpc = b.DataUltimoCpc
From misitau.dbo.Telefones a
inner join #Telefones b on a.IdTelefone = b.IdTelefone
Where
	not exists (Select 1
				From misitau.dbo.Telefones c
				Where a.IdTelefone = c.IdTelefone
				and a.DataAtualizacao = c.DataAtualizacao);


Set @LinhasAtualizadas = @@RowCount;
Set @LinhasTotaisDestino = @LinhasInseridas + @LinhasAtualizadas;
Set @DataHoraFim = Dateadd(hour,-3,Getdate());

/* Grava volumetria controles de log */
Exec misitau.[log].ProcControles
    @TipoLog = 'Volumetria',
    @IdExecucao = @IdExecucao,
    @NomeTabelaOrigem = 'cob.Telefones',
    @NomeTabelaDestino = 'dbo.Telefones',
    @LinhasOrigem = @LinhasOrigem,
    @LinhasInseridas = @LinhasInseridas,
    @LinhasAtualizadas = @LinhasAtualizadas,
    @LinhasTotaisDestino = @LinhasTotaisDestino;

/* Finaliza execução controles de log concluido */
Exec misitau.[log].ProcControles
    @TipoLog = 'Atualizacao',
    @IdExecucao = @IdExecucao,
    @DataHoraFim = @DataHoraFim,
    @StatusExecucao = 'Concluida';


End Try
Begin Catch

Set @MensagemErro = Error_message();
Set @NumeroErro = Error_number();
Set @LinhaErro = Error_line()


/* Finalizacao execução de log erro */
Set @DataHoraFim = Dateadd(hour,-3,Getdate());
Exec misitau.[log].ProcControles
    @TipoLog = 'Atualizacao',
    @IdExecucao = @IdExecucao,
    @DataHoraFim = @DataHoraFim,
    @StatusExecucao = 'Erro';

/* Execução log erro */
Exec misitau.[log].ProcControles
    @TipoLog = 'Erro',
    @IdExecucao = @IdExecucao,
    @NomeProcedure = @NomeProcedure,
    @MensagemErro = @MensagemErro,
    @NumeroErro = @NumeroErro,
    @LinhaErro = @LinhaErro,
    @EtapaErro = @Etapa;

End Catch;
	