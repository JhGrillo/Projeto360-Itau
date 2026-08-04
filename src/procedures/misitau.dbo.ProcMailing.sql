Create or Alter Procedure dbo.ProcMailing as

------------------------------> Descrição da procedure

/*
    Padrão de escrita: PascalCase
    Nome: ProcAcordosParcelasPagar
    DataCriação: 03/08/2026
    Criado por: Leonardo Matheus Talarico
    DataAtualização: 
    Atualizado por:

    Descrição atualização: (Data, Atualizado por, Descrição, git)

*/

------------------------------> Definições de variaveis e controles de ambiente

Set Nocount On;

Declare @NomeProcedure varchar(128) = 'ProcMailing',
        @Etapa varchar(100) = 'Inicio',
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

--- | Origem

if Object_id(N'Tempdb..#DadosOrigem') is not null Drop Table #DadosOrigem 
Create Table #DadosOrigem (
    IdDevedor int,
    IdCarteira int,
    IdRetirada int
);

--- | Mailing

if Object_id(N'Tempdb..#Mailing') is not null Drop Table #Mailing 
Create Table #Mailing (
    IdDevedor int,
    IdCarteira int,
    IdRetirada int
);

--- | Devolucoes

if Object_id(N'Tempdb..#Devolucoes') is not null Drop Table #Devolucoes  
Create Table #Devolucoes (
    IdDevedor int,
    IdCarteira int
);

------------------------------> Carga das tabelas temporarias

Set @Etapa = 'Carga das tabelas temporarias';

--- | Insere novos acordos na tabela de origem

Insert into #DadosOrigem (
                          IdCarteira,
                          IdDevedor
                          )
Select 
    IdCarteira,
    IdDevedor
From misitau.log.Mailing;

/* Cria index clusterizado 
Obs: Este index é criado fora da etapa de index devido a necessidade de performance no comparativo abaixo.
*/
Create nonclustered Index IxMailing on #DadosOrigem (IdDevedor, IdCarteira);

--- | Devolucoes

With DevolucoesCTE as (
    Select distinct
        b.IdCarteira,
        b.IdDevedor
    From misitau.cob.Parcelas a
    Inner join misitau.cob.Titulos b on a.IdTitulo = b.IdTitulo
    Where
        Convert(date, a.DataDevolucao) = Convert(date, Dateadd(hour,-3,Getdate()))
),

AtivosCTE as (
    Select
        b.IdCarteira,
        b.IdDevedor
    From misitau.cob.Parcelas a 
    Inner join misitau.cob.Titulos b on a.IdTitulo = b.IdTitulo
    Where
        a.IdSituacaoParcela = 'A'
)

Insert into #Devolucoes (
                        IdCarteira,
                        IdDevedor
                        )
Select
    IdCarteira,
    IdDevedor
From DevolucoesCTE a
Where
    Not exists (Select 1
                From AtivosCTE b
                Where
                    a.IdCarteira = b.IdCarteira
                    and a.IdDevedor = b.IdDevedor);

--- | Mailing

Insert into #Mailing (
                     IdCarteira,
                     IdDevedor
                     )
Select
    IdCarteira,
    IdDevedor
From #DadosOrigem a
Where 
    Not exists (Select 1
                From misitau.dbo.Mailing b With(nolock)
                Where 
                    a.IdDevedor = b.IdDevedor
                    and a.IdCarteira = b.IdCarteira);

Set @LinhasOrigem = @@RowCount;

------------------------------> Criacao de índices

Set @Etapa = 'Criacao de indices';

/* Cria index não clusterizado */

Create nonclustered index IxMailing on #Mailing (IdDevedor, IdCarteira);

------------------------------> Persistencia final

Set @Etapa = 'Persistencia final';

--- | Tabela fisica

Insert into misitau.dbo.Mailing (
                                IdCarteira,
                                IdDevedor
                                )
Select
    a.IdCarteira,
    a.IdDevedor
From #Mailing a
Where
    Not exists (Select 1
                From misitau.dbo.Mailing b With(nolock)
                Where
                    a.IdDevedor = b.IdDevedor
                    and a.IdCarteira = b.IdCarteira);

Set @LinhasInseridas = @@RowCount;

------------------------------> Atualizacao de dados

Set @Etapa = 'Atualizacao de dados';

--- | Atualiza campos da tabela fisica

/*
    1 - Devolucoes
    2 - Exclusao mailing
*/

Update a
Set a.IdRetirada = 1
From misitau.dbo.Mailing a
Where
    Exists (Select 1
            From #Devolucoes b
            Where
                a.IdCarteira = b.IdCarteira
                and a.IdDevedor = b.IdDevedor);

Set @LinhasAtualizadas = @@RowCount;

Update a
Set a.IdRetirada = 2
From misitau.dbo.Mailing a
WHere
    Not Exists (Select 1
                From misitau.dbo.Mailing b
                Where
                    a.IdCarteira = b.IdCarteira
                    and a.IdDevedor = b.IdCarteira);

Set @LinhasAtualizadas += @@RowCount;
Set @LinhasTotaisDestino = @LinhasInseridas + isnull(@LinhasAtualizadas, 0);
Set @DataHoraFim = Dateadd(hour,-3,Getdate());

/* Grava volumetria controles de log */
Exec misitau.[log].ProcControles
    @TipoLog = 'Volumetria',
    @IdExecucao = @IdExecucao,
    @NomeTabelaOrigem = 'log.Mailing',
    @NomeTabelaDestino = 'dbo.Mailing',
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
Set @LinhaErro = Error_line();

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