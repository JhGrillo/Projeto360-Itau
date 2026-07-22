Create or Alter Procedure [dbo].[ProcParcelas] as

------------------------------> Descrição da procedure

/*
    Padrão de escrita: PascalCase
    Nome: ProcParcelas
    DataCriação: 22/07/2026
    Criado por: João Henrique Cavalheiro Grillo
    DataAtualização:
    Atualizado por:

    Descrição atualização: (Data, Atualizado por, Descrição, git)
*/

------------------------------> Definições de variaveis e controles de ambiente

Set nocount on;

Declare @NomeProcedure varchar(128) = 'ProcParcelas',
    @Etapa varchar(100) = 'Inicio',
    @UltimaAtualizacao datetime,
    @Tabela varchar(25),
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

Begin try

------------------------------> Carga das tabelas temporarias

Set @Etapa = 'Carga das tabelas temporarias';

--- | Insere novas parcelas na tabela

Set @UltimaAtualizacao = (Select 
                            Case
                                when Datepart(hour,Max(DataHoraInicio)) >= 22 then Max(Dateadd(day,+1,Convert(date,DataHoraInicio)))
                                else Max(Convert(date,DataHoraInicio))
                            end
                         From misitau.[log].ControleExecucoes
                         Where
                            NomeProcedure = 'ProcParcelas'
                            and StatusExecucao = 'Concluida');

If (Select top 1 IdParcela From misitau.dbo.Parcelas) is null 
Begin

    If Object_id('Tempdb..#ParcelasAbertas') Is not null Drop table #ParcelasAbertas;
    Select
        a.IdParcela,
        a.IdTitulo,
        a.IdOrigem,
        a.NumeroParcela,
        a.Tipo,
        a.IdSituacaoParcela,
        a.ValorPrincipal,
        a.DataVencimento,
        a.DataPrevisaoDevolucao,
        a.DataDevolucao,
        a.IdMotivoDevolucao,
        a.DataInclusao,
        a.IdUsuarioInclusao,
        a.DataAtualizacao,
        a.IdUsuarioAtualizacao,
        a.DataExclusao,
        a.IdUsuarioExclusao,
        a.ValidoDe,
        a.ValidoAte
    Into #ParcelasAbertas
    From misitau.cob.Parcelas a
    Where
        a.IdSituacaoParcela = 'A'
        or a.DataAtualizacao >= @UltimaAtualizacao;

    Set @LinhasOrigem = @@RowCount;
    Set @Tabela = '#ParcelasAbertas';

end
Else begin

    If Object_id('Tempdb..#ParcelasAtualizadas') Is not null Drop table #ParcelasAtualizadas;
    Select
        a.IdParcela,
        a.IdTitulo,
        a.IdOrigem,
        a.NumeroParcela,
        a.Tipo,
        a.IdSituacaoParcela,
        a.ValorPrincipal,
        a.DataVencimento,
        a.DataPrevisaoDevolucao,
        a.DataDevolucao,
        a.IdMotivoDevolucao,
        a.DataInclusao,
        a.IdUsuarioInclusao,
        a.DataAtualizacao,
        a.IdUsuarioAtualizacao,
        a.DataExclusao,
        a.IdUsuarioExclusao,
        a.ValidoDe,
        a.ValidoAte
    into #ParcelasAtualizadas
    From misitau.cob.Parcelas a
    Where
        (a.DataAtualizacao >= @UltimaAtualizacao
        or a.DataInclusao >= @UltimaAtualizacao)
        and Not exists (Select
                            1
                        From misitau.dbo.Parcelas b With(nolock)
                        Where
                            a.IdParcela = b.IdParcela
                            and Isnull(a.DataAtualizacao,'1900-01-01') = Isnull(b.DataAtualizacao,'1900-01-01'));

    Set @LinhasOrigem = @@RowCount;
    Set @Tabela = '#ParcelasAtualizadas';

end;

------------------------------> Criacao de índices

Set @Etapa = 'Criacao de indices';

/* Cria index não clusterizado */
If @Tabela = '#ParcelasAbertas' 
Begin 
    Create nonclustered index IxParcelas on #ParcelasAbertas (IdParcela);
End
Else Begin 
    Create nonclustered index IxParcelas on #ParcelasAtualizadas (IdParcela);
End;

------------------------------> Persistencia final

Set @Etapa = 'Persistencia final';

--- | Tabela fisica

Declare @SQL nvarchar(max) = N'
Insert into misitau.dbo.Parcelas (
                                IdParcela,
                                IdTitulo,
                                IdOrigem,
                                NumeroParcela,
                                Tipo,
                                IdSituacaoParcela,
                                ValorPrincipal,
                                DataVencimento,
                                DataPrevisaoDevolucao,
                                DataDevolucao,
                                IdMotivoDevolucao,
                                DataInclusao,
                                IdUsuarioInclusao,
                                DataAtualizacao,
                                IdUsuarioAtualizacao,
                                DataExclusao,
                                IdUsuarioExclusao,
                                ValidoDe,
                                ValidoAte
                                )
Select
    IdParcela,
    IdTitulo,
    IdOrigem,
    NumeroParcela,
    Tipo,
    IdSituacaoParcela,
    ValorPrincipal,
    DataVencimento,
    DataPrevisaoDevolucao,
    DataDevolucao,
    IdMotivoDevolucao,
    DataInclusao,
    IdUsuarioInclusao,
    DataAtualizacao,
    IdUsuarioAtualizacao,
    DataExclusao,
    IdUsuarioExclusao,
    ValidoDe,
    ValidoAte
From ' + @Tabela + ' a
Where
    Not exists (Select 1
                From misitau.dbo.Parcelas b With(nolock)
                Where
                    a.IdParcela = b.IdParcela)';

Exec sp_executesql @SQL;

Set @LinhasInseridas = @@RowCount;

------------------------------> Atualizacao de dados

Set @Etapa = 'Atualizacao de dados';

--- | Atualiza campos da tabela fisica

If @Tabela = '#ParcelasAtualizadas'
begin

    Update a
    Set a.IdOrigem = b.IdOrigem,
        a.Tipo = b.Tipo,
        a.IdSituacaoParcela = b.IdSituacaoParcela,
        a.DataPrevisaoDevolucao = b.DataPrevisaoDevolucao,
        a.DataDevolucao = b.DataDevolucao,
        a.IdMotivoDevolucao = b.IdMotivoDevolucao,
        a.DataAtualizacao = b.DataAtualizacao,
        a.IdUsuarioAtualizacao = b.IdUsuarioAtualizacao,
        a.DataExclusao = b.DataExclusao,
        a.IdUsuarioExclusao = b.IdUsuarioExclusao,
        a.ValidoDe = b.ValidoDe,
        a.ValidoAte = b.ValidoAte
    From misitau.dbo.Parcelas a With(nolock)
    inner join #ParcelasAtualizadas b on a.IdParcela = b.IdParcela
    Where
        Isnull(a.DataAtualizacao, '1900-01-01') <> Isnull(b.DataAtualizacao, '1900-01-01');

end;

Set @LinhasAtualizadas = @@RowCount;
Set @LinhasTotaisDestino = @LinhasInseridas + Isnull(@LinhasAtualizadas,0);
Set @DataHoraFim = Dateadd(hour,-3,Getdate());

/* Grava volumetria controles de log */
Exec misitau.[log].ProcControles
    @TipoLog = 'Volumetria',
    @IdExecucao = @IdExecucao,
    @NomeTabelaOrigem = 'cob.Parcelas',
    @NomeTabelaDestino = 'dbo.Parcelas',
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