Create or Alter procedure [dbo].[ProcTitulos] as

------------------------------> Descrição da procedure

/*
    Padrão de escrita: PascalCase
    Nome: ProcTitulos
    DataCriação: 23/07/2026
    Criado por: Leonardo Matheus Talarico
    DataAtualização:
    Atualizado por:

    Descrição atualização: (Data, Atualizado por, Descrição, git)
*/

------------------------------> Definições de variaveis e controles de ambiente

Set nocount on;

Declare @NomeProcedure varchar(128) = 'ProcTitulos',
    @Etapa varchar(100) = 'Inicio',
    @IdTitulo int,
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
    @IdExecucao = @IdExecucao OUTPUT

Begin try
------------------------------> Criacao das tabelas temporarias

Set @Etapa = 'Criacao das tabelas temporarias';

--- | Titulos

If Object_id('Tempdb..#Titulos') Is not null Drop table #Titulos;
Create table #Titulos (
    IdTitulo int,
    IdEmpresa tinyint,
    IdDevedor int,
    IdCarteira smallint,
    IdProduto smallint,
    IdOrigem tinyint,
    NumeroContrato varchar(32),
    Plano smallint,
    PercentualJurosRemuneratorios float,
    DataInclusao datetime,
    IdUsuarioInclusao int,
    DataAtualizacao datetime,
    IdUsuarioAtualizacao int,
    DataExclusao datetime,
    IdUsuarioExclusao int,
    Suspenso char(1),
    ValidoDe datetime,
    ValidoAte datetime
);

------------------------------> Carga das tabelas temporarias

Set @Etapa = 'Carga das tabelas temporarias';

--- | Insere devedores novos ou atualizados

Set @IdTitulo = (Select Max(IdTitulo) From misitau.dbo.Titulos With(nolock));
Set @UltimaAtualizacao = (Select 
                            Case
                                when Datepart(hour,Max(DataHoraInicio)) >= 22 then Max(Dateadd(day,+1,Convert(date,DataHoraInicio)))
                                else Max(Convert(date,DataHoraInicio))
                            end
                          From misitau.[log].ControleExecucoes
                          Where
                            NomeProcedure = 'ProcTitulos'
                            and StatusExecucao = 'Concluida');

Insert into #Titulos (
                    IdTitulo,
                    IdEmpresa,
                    IdDevedor,
                    IdCarteira,
                    IdProduto,
                    IdOrigem,
                    NumeroContrato,
                    Plano,
                    PercentualJurosRemuneratorios,
                    DataInclusao,
                    IdUsuarioInclusao,
                    DataAtualizacao,
                    IdUsuarioAtualizacao,
                    DataExclusao,
                    IdUsuarioExclusao,
                    Suspenso,
                    ValidoDe,
                    ValidoAte
                    )
Select
    IdTitulo,
    IdEmpresa,
    IdDevedor,
    IdCarteira,
    IdProduto,
    IdOrigem,
    NumeroContrato,
    Plano,
    PercentualJurosRemuneratorios,
    DataInclusao,
    IdUsuarioInclusao,
    DataAtualizacao,
    IdUsuarioAtualizacao,
    DataExclusao,
    IdUsuarioExclusao,
    ValidoDe,
    ValidoAte
From misitau.cob.Titulos a
Where
    (IdTitulo > @IdTitulo
    or DataAtualizacao >= @UltimaAtualizacao)
    and Not exists (Select 1
                    From misitau.dbo.Titulos b With(nolock)
                    Where
                        a.IdTitulo = b.IdTitulo
                        and Isnull(a.DataAtualizacao,'1900-01-01') = Isnull(b.DataAtualizacao,'1900-01-01'));

Set @LinhasOrigem = @@RowCount;

------------------------------> Criacao de indices

Set @Etapa = 'Criacao de indices';

/* Cria index não clusterizado */
Create nonclustered index IxTitulo on #Titulos (IdTitulo);

------------------------------> Persistencia final

Set @Etapa = 'Persistencia final';

--- | Tabela fisica

Insert into misitau.dbo.Titulos (
                        IdTitulo,
                        IdEmpresa,
                        IdDevedor,
                        IdCarteira,
                        IdProduto,
                        IdOrigem,
                        NumeroContrato,
                        Plano,
                        PercentualJurosRemuneratorios,
                        DataInclusao,
                        IdUsuarioInclusao,
                        DataAtualizacao,
                        IdUsuarioAtualizacao,
                        DataExclusao,
                        IdUsuarioExclusao,
                        Suspenso,
                        ValidoDe,
                        ValidoAte
                        )
Select distinct
    IdTitulo,
    IdEmpresa,
    IdDevedor,
    IdCarteira,
    IdProduto,
    IdOrigem,
    NumeroContrato,
    Plano,
    PercentualJurosRemuneratorios,
    DataInclusao,
    IdUsuarioInclusao,
    DataAtualizacao,
    IdUsuarioAtualizacao,
    DataExclusao,
    IdUsuarioExclusao,
    Suspenso,
    ValidoDe,
    ValidoAte
From #Titulos a With(nolock)
Where
    Not exists (Select 1
                From misitau.dbo.Titulos b With(nolock)
                Where
                 a.IdTitulo = b.IdTitulo);

Set @LinhasInseridas = @@RowCount;

------------------------------> Atualizacao de dados

Set @Etapa = 'Atualizacao de dados';

--- | Atualiza campos da tabela fisica

Update a
Set a.IdCarteira = b.IdCarteira,
    a.Plano = b.Plano,
    a.PercentualJurosRemuneratorios = b.PercentualJurosRemuneratorios,
    a.DataAtualizacao = b.DataAtualizacao,
    a.IdUsuarioAtualizacao = b.IdUsuarioAtualizacao,
    a.DataExclusao = b.DataExclusao,
    a.IdUsuarioExclusao = b.IdUsuarioExclusao,
    a.Suspenso = b.Suspenso
From misitau.dbo.Titulos a With(nolock)
Inner join #Titulos b With(nolock) on a.IdTitulo = b.IdTitulo
Where
    Isnull(a.DataAtualizacao,'1900-01-01') <> Isnull(b.DataAtualizacao,'1900-01-01');

Set @LinhasAtualizadas = @@RowCount;
Set @LinhasTotaisDestino = @LinhasInseridas + @LinhasAtualizadas;
Set @DataHoraFim = Dateadd(hour,-3,Getdate());

/* Grava volumetria controles de log */
Exec misitau.[log].ProcControles
    @TipoLog = 'Volumetria',
    @IdExecucao = @IdExecucao,
    @NomeTabelaOrigem = 'cob.Titulos',
    @NomeTabelaDestino = 'dbo.Titulos',
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