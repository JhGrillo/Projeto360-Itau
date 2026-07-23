Create or Alter procedure [dbo].[ProcUsuarios] as

------------------------------> Descrição da procedure

/*
    Padrão de escrita: PascalCase
    Nome: ProcUsuarios
    DataCriação: 23/07/2026
    Criado por: Leonardo Matheus Talarico
    DataAtualização:
    Atualizado por:

    Descrição atualização: (Data, Atualizado por, Descrição, git)
*/

------------------------------> Definições de variaveis e controles de ambiente

Set Nocount On;

Declare @NomeProcedure varchar(128) = 'ProcUsuarios',
        @Etapa varchar(100) = 'Inicio',
        @IdUsuario int,
        @UltimaAtualizacao datetime,
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

------------------------------> Criacao de tabelas temporarias

Set @Etapa = 'Criacao das tabelas temporarias';

--- | Usuarios

If Object_id('Tempdb..#Usuarios') Is not null Drop table #Usuarios;
Create table #Usuarios (
    IdUsuario int,
    Nome varchar(128),
    Referencia varchar(64),
    DataAdmissao datetime,
    DataDemissao datetime,
    DataAtualizacao datetime
);

------------------------------> Carga das tabelas temporarias

Set @Etapa = 'Carga das tabelas temporarias';

--- | Insere novos usuarios e atualizados

Set @IdUsuario = (Select Max(IdUsuario) From misitau.dbo.Usuarios With(nolock));
Set @UltimaAtualizacao = (Select 
                            Case
                                when Datepart(hour,Max(DataHoraInicio)) >= 22 then Max(Dateadd(day,+1,Convert(date,DataHoraInicio)))
                                else Max(Convert(date,DataHoraInicio))
                            end
                         From misitau.[log].ControleExecucoes
                         Where
                            NomeProcedure = 'ProcUsuarios'
                            and StatusExecucao = 'Concluida');

Insert into #Usuarios (
                       IdUsuario,
                       Nome,
                       Referencia,
                       DataAdmissao,
                       DataDemissao,
                       DataAtualizacao
                        )
Select
    IdUsuario,
    Nome,
    Referencia,
    DataAdmissao,
    DataDemissao,
    DataAtualizacao
From misitau.glo.Usuarios a
Where
    (IdUsuario >= @IdUsuario
    or DataAtualizacao >= @UltimaAtualizacao)
    and Not exists (Select 1
                    From misitau.dbo.Usuarios b With(nolock)
                    Where
                        a.IdUsuario = b.IdUsuario
                        and Isnull(a.DataAtualizacao,'1900-01-01') = Isnull(b.DataAtualizacao,'1900-01-01'));

Set @LinhasOrigem = @@RowCount;

------------------------------> Criacao de índices

Set @Etapa = 'Criacao de indices';

/* Cria index não clusterizado */
Create nonclustered index IxUsuarios on #Usuarios (IdUsuario);

------------------------------> Persistencia final

Set @Etapa = 'Persistencia final';

--- | Tabela fisica

Insert into misitau.dbo.Usuarios (
                                IdUsuario,
                                Nome,
                                Referencia,
                                DataAdmissao,
                                DataDemissao,
                                DataAtualizacao
                                )
Select distinct
    IdUsuario,
    Nome,
    Referencia,
    DataAdmissao,
    DataDemissao,
    DataAtualizacao
From #Usuarios a With(nolock)
Where
 Not exists (Select 1
            From misitau.dbo.Usuarios b With(nolock)
            Where
                a.IdUsuario = b.IdUsuario);

Set @LinhasInseridas = @@RowCount;

------------------------------> Atualizacao de dados

Set @Etapa = 'Atualizacao de dados';

--- | Atualiza campos da tabela fisica

Update a
Set a.Nome = b.Nome,
    a.Referencia = b.Referencia,
    a.DataAdmissao = b.DataAdmissao,
    a.DataDemissao = b.DataDemissao,
    a.DataAtualizacao = b.DataAtualizacao
From misitau.dbo.Usuarios a With(nolock)
Inner join #Usuarios b With(nolock) on a.IdUsuario = b.IdUsuario
Where
	Isnull(a.DataAtualizacao,'1900-01-01') <> Isnull(b.DataAtualizacao,'1900-01-01');

Set @LinhasAtualizadas = @@RowCount;
Set @LinhasTotaisDestino = @LinhasInseridas + @LinhasAtualizadas;
Set @DataHoraFim = Dateadd(hour,-3,Getdate());

/* Grava volumetria controles de log */
Exec misitau.[log].ProcControles
    @TipoLog = 'Volumetria',
    @IdExecucao = @IdExecucao,
    @NomeTabelaOrigem = 'glo.Usuarios',
    @NomeTabelaDestino = 'dbo.Usuarios',
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