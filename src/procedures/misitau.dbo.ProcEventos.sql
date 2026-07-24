Create or Alter procedure dbo.ProcEventos as

------------------------------> Descrição da procedure

/*
    Padrão de escrita: PascalCase
    Nome: ProcEventos
    DataCriação: 24/07/2026
    Criado por: João Henrique Cavalheiro Grillo
    DataAtualização:
    Atualizado por:

    Descrição atualização: (Data, Atualizado por, Descrição, git)
*/

------------------------------> Definições de variaveis e controles de ambiente

Set nocount on;

Declare @NomeProcedure varchar(128) = 'ProcEventos',
        @Etapa varchar(100) = 'Inicio',
        @IdEvento int,
        @UltimaAtualizacao datetime,
        @SQLEventos nvarchar(max),
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

--- | Eventos

If Object_id('Tempdb..#Eventos') Is not null Drop table #Eventos;
Create table #Eventos (
    IdEvento int,
    IdDevedor int,
    IdTitulo int,
    IdParcela int,
    IdTipoEvento smallint,
    IdOrigem tinyint,
    IdLigacao int,
    DataEvento datetime,
    DataComplementar datetime,
    Complemento varchar(max),
    DataInclusao datetime,
    IdUsuarioInclusao int,
    DataAtualizacao datetime,
    IdUsuarioAtualizacao int
);

------------------------------> Carga das tabelas temporarias

Set @Etapa = 'Carga das tabelas temporarias';

Set @IdEvento = (Select Max(IdEvento) From misitau.dbo.Eventos With(nolock));

Set @UltimaAtualizacao = (Select 
							Case
								when Datepart(hour,Max(DataHoraInicio)) >= 22 then Max(Dateadd(day,+1,Convert(date,DataHoraInicio)))
								else Max(Convert(date,DataHoraInicio))
							end
						  From misitau.[log].ControleExecucoes
						  Where
							NomeProcedure = 'ProcEventos'
							and StatusExecucao = 'Concluida');

Set @SQLEventos = N'
Insert into #Eventos (
                    IdEvento,
                    IdDevedor,
                    IdTitulo,
                    IdParcela,
                    IdTipoEvento,
                    IdOrigem,
                    IdLigacao,
                    DataEvento,
                    DataComplementar,
                    Complemento,
                    DataInclusao,
                    IdUsuarioInclusao,
                    DataAtualizacao,
                    IdUsuarioAtualizacao
                    )
Select
    IdEvento,
    IdDevedor,
    IdTitulo,
    IdParcela,
    IdTipoEvento,
    IdOrigem,
    IdLigacao,
    DataEvento,
    DataComplementar,
    Complemento,
    DataInclusao,
    IdUsuarioInclusao,
    DataAtualizacao,
    IdUsuarioAtualizacao
From oco.Eventos a
Where
    ' + Case 
            when @IdEvento is null then 'DataEvento >= ''' + Convert(nvarchar(120),@UltimaAtualizacao) + '''' 
            else 'IdEvento > ' + Convert(nvarchar,@IdEvento) 
        end;

Exec sp_executesql @SQLEventos;

Set @LinhasOrigem = @@RowCount;

------------------------------> Criacao de indices

Set @Etapa = 'Criacao de indices';

/* Cria index não clusterizado */
Create nonclustered index IxEvento on #Eventos (IdEvento);

------------------------------> Persistencia final

Set @Etapa = 'Persistencia final';

--- | Tabela fisica

Insert into dbo.Eventos (
                    IdEvento,
                    IdDevedor,
                    IdTitulo,
                    IdParcela,
                    IdTipoEvento,
                    IdOrigem,
                    IdLigacao,
                    DataEvento,
                    DataComplementar,
                    Complemento,
                    DataInclusao,
                    IdUsuarioInclusao,
                    DataAtualizacao,
                    IdUsuarioAtualizacao
                    )
Select
    IdEvento,
    IdDevedor,
    IdTitulo,
    IdParcela,
    IdTipoEvento,
    IdOrigem,
    IdLigacao,
    DataEvento,
    DataComplementar,
    Complemento,
    DataInclusao,
    IdUsuarioInclusao,
    DataAtualizacao,
    IdUsuarioAtualizacao
From #Eventos a With(nolock)
Where
    Not exists (Select 1
                From dbo.Eventos b With(nolock)
                Where
                    a.IdEvento = b.IdEvento);

Set @LinhasInseridas = @@RowCount;
Set @LinhasTotaisDestino = @LinhasInseridas;
Set @DataHoraFim = Dateadd(hour,-3,Getdate());

/* Grava volumetria controles de log */
Exec misitau.[log].ProcControles
    @TipoLog = 'Volumetria',
    @IdExecucao = @IdExecucao,
    @NomeTabelaOrigem = 'oco.Eventos',
    @NomeTabelaDestino = 'dbo.Eventos',
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