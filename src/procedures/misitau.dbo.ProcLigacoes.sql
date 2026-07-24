Create or Alter procedure [dbo].[ProcLigacoes] as

------------------------------> Descrição da procedure

/*
    Padrão de escrita: PascalCase
    Nome: ProcLigacoes
    DataCriação: 24/07/2026
    Criado por: Leonardo Matheus talarico
    DataAtualização:
    Atualizado por:

    Descrição atualização: (Data, Atualizado por, Descrição, git)
*/

------------------------------> Definições de variaveis e controles de ambiente

Set nocount on;

Declare @NomeProcedure varchar(128) = 'ProcLigacoes',
    @Etapa varchar(100) = 'Inicio',
    @IdLigacao int,
    @UltimaAtualizacao datetime,
    @SQLLigacao nvarchar(max),
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
    @IdExecucao = @IdExecucao OUTPUT

Begin try

------------------------------> Criacao das tabelas temporarias

Set @Etapa = 'Criacao das tabelas temporarias';

--- | Ligações

If Object_id('Tempdb..#Ligacoes') Is not null Drop table #Ligacoes;
Create table #Ligacoes (
	IdLigacao int,
	Chave varchar(256),
	IdDiscador tinyint,
	IdOrigemLigacao char(1),
	IdTelefoneLigacao int,
	UFLigacao char(2),
	DDDLigacao char(2),
	NumeroLigacao char(9),
	DataFinalizacao datetime,
	IdTelefoneAgendamento int,
	UFAgendamento char(2),
	DDDAgendamento char(2),
	NumeroAgendamento char(9),
	DataAgendamento datetime,
	AgendamentoFidelizado char(1),
	DataInicializacao datetime,
	IdUsuarioAllure int,
	IdUsuarioDiscador int,
	IdDevedor int
);

------------------------------> Carga das tabelas temporarias

Set @Etapa = 'Carga das tabelas temporarias';

--- | Ligações

Set @IdLigacao = (Select Max(IdLigacao) From misitau.dbo.Ligacoes With(nolock));

Set @UltimaAtualizacao = (Select 
                            Case
                                when Datepart(hour,Max(DataHoraInicio)) >= 22 then Max(Dateadd(day,+1,Convert(date,DataHoraInicio)))
                                else Max(Convert(date,DataHoraInicio))
                            end
                         From misitau.[log].ControleExecucoes
                         Where
                            NomeProcedure = 'ProcLigacoes'
                            and StatusExecucao = 'Concluida');

Set @SQLLigacao = N'
Insert into #Ligacoes (
                    IdLigacao,
                    Chave,
                    IdDiscador,
                    IdOrigemLigacao,
                    IdTelefoneLigacao,
                    UfLigacao,
                    DDDLigacao,
                    NumeroLigacao,
                    DataFinalizacao,
                    IdTelefoneAgendamento,
                    UFAgendamento,
                    DDDAgendamento,
                    NumeroAgendamento,
                    DataAgendamento,
                    AgendamentoFidelizado,
                    DataInicializacao,
                    IdUsuarioAllure,
                    IdUsuarioDiscador,
                    IdDevedor
                    )
Select
    IdLigacao,
    Chave,
    IdDiscador,
    IdOrigemLigacao,
    IdTelefoneLigacao,
    UfLigacao,
    DDDLigacao,
    NumeroLigacao,
    DataFinalizacao,
    IdTelefoneAgendamento,
    UFAgendamento,
    DDDAgendamento,
    NumeroAgendamento,
    DataAgendamento,
    AgendamentoFidelizado,
    DataInicializacao,
    IdUsuarioAllure,
    IdUsuarioDiscador,
    IdDevedor
From misitau.lig.Ligacoes a
Where
    ' + Case 
            when @IdLigacao is null then 'DataInicializacao >= ''' + Convert(nvarchar(120),@UltimaAtualizacao) + '''' 
            else 'IdLigacao > ' + Convert(nvarchar,@IdLigacao) 
        end;

Exec sp_executesql @SQLLigacao;

Set @LinhasOrigem = @@RowCount;

------------------------------> Criacao de indices

Set @Etapa = 'Criacao de indices';

/* Cria index nonclusterizados */
Create nonclustered index IxLigacoes on #Ligacoes (IdLigacao);

------------------------------> Persistencia final

Set @Etapa = 'Persistencia final';

--- | Tabela fisica

Insert into misitau.dbo.Ligacoes (
                            IdLigacao,
                            Chave,
                            IdDiscador,
                            IdOrigemLigacao,
                            IdTelefoneLigacao,
                            UfLigacao,
                            DDDLigacao,
                            NumeroLigacao,
                            DataFinalizacao,
                            IdTelefoneAgendamento,
                            UFAgendamento,
                            DDDAgendamento,
                            NumeroAgendamento,
                            DataAgendamento,
                            AgendamentoFidelizado,
                            DataInicializacao,
                            IdUsuarioAllure,
                            IdUsuarioDiscador,
                            IdDevedor
                            )
Select
    IdLigacao,
    Chave,
    IdDiscador,
    IdOrigemLigacao,
    IdTelefoneLigacao,
    UfLigacao,
    DDDLigacao,
    NumeroLigacao,
    DataFinalizacao,
    IdTelefoneAgendamento,
    UFAgendamento,
    DDDAgendamento,
    NumeroAgendamento,
    DataAgendamento,
    AgendamentoFidelizado,
    DataInicializacao,
    IdUsuarioAllure,
    IdUsuarioDiscador,
    IdDevedor
From #Ligacoes a With(nolock)
Where
    Not exists (Select 1
                From misitau.dbo.Ligacoes b With(nolock)
                Where
                 a.IdLigacao = b.IdLigacao);

Set @LinhasInseridas = @@RowCount;
Set @LinhasTotaisDestino = @LinhasInseridas;
Set @DataHoraFim = Dateadd(hour,-3,Getdate());

/* Grava volumetria controles de log */
Exec misitau.[log].ProcControles
    @TipoLog = 'Volumetria',
    @IdExecucao = @IdExecucao,
    @NomeTabelaOrigem = 'lig.Ligacoes',
    @NomeTabelaDestino = 'dbo.Ligacoes',
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