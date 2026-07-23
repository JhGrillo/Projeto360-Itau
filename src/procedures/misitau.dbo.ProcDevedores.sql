Create or Alter procedure dbo.ProcDevedores as

------------------------------> Descrição da procedure

/*
    Padrão de escrita: PascalCase
    Nome: ProcDevedores
    DataCriação: 23/07/2026
    Criado por: João Henrique Cavalheiro Grillo
    DataAtualização:
    Atualizado por:

    Descrição atualização: (Data, Atualizado por, Descrição, git)
*/

------------------------------> Definições de variaveis e controles de ambiente

Set Nocount On;

Declare @NomeProcedure varchar(128) = 'ProcDevedores',
        @Etapa varchar(100) = 'Inicio',
        @IdDevedor int,
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

--- | Devedores informações complementares

If Object_id('Tempdb..#Devedores') Is not null Drop table #Devedores;
Create table #Devedores (
    IdDevedor int,
    IdOrigem tinyint,
    CnpjCpf char(14),
    RG char(9),
    RazaoSocialNome varchar(128),
    DataInclusao datetime,
    IdUsuarioInclusao int,
    DataAtualizacao datetime,
    IdUsuarioAtualizacao int,
    DataExclusao datetime,
    IdUsuarioExclusao int,
    IdUltimoEnriquecimento int,
    Apelido varchar(64),
    ValidoDe datetime,
    ValidoAte datetime
);

------------------------------> Carga das tabelas temporarias

Set @Etapa = 'Carga das tabelas temporarias';

--- | Insere novos devedores na tabela

Set @IdDevedor = (Select Max(IdDevedor) From misitau.dbo.Devedores With(nolock));
Set @UltimaAtualizacao = (Select 
                            Case
                                when Datepart(hour,Max(DataHoraInicio)) >= 22 then Max(Dateadd(day,+1,Convert(date,DataHoraInicio)))
                                else Max(Convert(date,DataHoraInicio))
                            end
                          From misitau.[log].ControleExecucoes
                          Where
                            NomeProcedure = 'ProcDevedores'
                            and StatusExecucao = 'Concluida');
Insert into #Devedores (
                        IdDevedor,
                        IdOrigem,
                        CnpjCpf,
                        RG,
                        RazaoSocialNome,
                        DataInclusao,
                        IdUsuarioInclusao,
                        DataAtualizacao,
                        IdUsuarioAtualizacao,
                        DataExclusao,
                        IdUsuarioExclusao,
                        IdUltimoEnriquecimento,
                        Apelido,
                        ValidoDe,
                        ValidoAte
                        )
Select
    IdDevedor,
    IdOrigem,
    CnpjCpf,
    RG,
    RazaoSocialNome,
    DataInclusao,
    IdUsuarioInclusao,
    DataAtualizacao,
    IdUsuarioAtualizacao,
    DataExclusao,
    IdUsuarioExclusao,
    IdUltimoEnriquecimento,
    Apelido,
    ValidoDe,
    ValidoAte
From misitau.cob.Devedores a
Where
    (IdDevedor >= @IdDevedor
    or DataAtualizacao >= @UltimaAtualizacao)
    and Not exists (Select 1
                    From misitau.dbo.Devedores b With(nolock)
                    Where
                        a.IdDevedor = b.IdDevedor
                        and Isnull(a.DataAtualizacao,'1900-01-01') = Isnull(b.DataAtualizacao,'1900-01-01'));

Set @LinhasOrigem = @@RowCount;

------------------------------> Criacao de índices

Set @Etapa = 'Criacao de indices';

/* Cria index não clusterizado */
Create nonclustered index IxDevedor on #Devedores (IdDevedor);

------------------------------> Persistencia final

Set @Etapa = 'Persistencia final';

--- | Tabela fisica

Insert into misitau.dbo.Devedores(
                              IdDevedor,
                              IdOrigem,
                              CnpjCpf,
                              RG,
                              RazaoSocialNome,
                              DataInclusao,
                              IdUsuarioInclusao,
                              DataAtualizacao,
                              IdUsuarioAtualizacao,
                              DataExclusao,
                              IdUsuarioExclusao,
                              IdUltimoEnriquecimento,
                              Apelido,
                              ValidoDe,
                              ValidoAte
                              )
Select distinct
    IdDevedor,
    IdOrigem,
    CnpjCpf,
    RG,
    RazaoSocialNome,
    DataInclusao,
    IdUsuarioInclusao,
    DataAtualizacao,
    IdUsuarioAtualizacao,
    DataExclusao,
    IdUsuarioExclusao,
    IdUltimoEnriquecimento,
    Apelido,
    ValidoDe,
    ValidoAte
From #Devedores a With(nolock)
Where
 Not exists (Select 1
             From misitau.dbo.Devedores b With(nolock)
             Where
                a.IdDevedor = b.IdDevedor);

Set @LinhasInseridas = @@RowCount;

------------------------------> Atualizacao de dados

Set @Etapa = 'Atualizacao de dados';

--- | Atualiza campos da tabela fisica

Update a
Set a.DataAtualizacao = b.DataAtualizacao,
    a.IdUsuarioAtualizacao = b.IdUsuarioAtualizacao,
    a.DataExclusao = b.DataExclusao,
    a.IdUsuarioExclusao = b.IdUsuarioExclusao,
    a.IdUltimoEnriquecimento = b.IdUltimoEnriquecimento,
    a.Apelido = b.Apelido
From misitau.dbo.Devedores a With(nolock)
Inner join #Devedores b With(nolock) on a.IdDevedor = b.IdDevedor
Where
	Isnull(a.DataAtualizacao,'1900-01-01') <> Isnull(b.DataAtualizacao,'1900-01-01');

Set @LinhasAtualizadas = @@RowCount;
Set @LinhasTotaisDestino = @LinhasInseridas + @LinhasAtualizadas;
Set @DataHoraFim = Dateadd(hour,-3,Getdate());

/* Grava volumetria controles de log */
Exec misitau.[log].ProcControles
    @TipoLog = 'Volumetria',
    @IdExecucao = @IdExecucao,
    @NomeTabelaOrigem = 'cob.Devedores',
    @NomeTabelaDestino = 'dbo.Devedores',
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