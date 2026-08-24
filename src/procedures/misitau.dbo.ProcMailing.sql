------------------------------> Descrição da procedure

/*
    Padrão de escrita: PascalCase
    Nome: ProcMailing
    DataCriação: 03/08/2026
    Criado por: Leonardo Matheus Talarico
    DataAtualização: 18/08/2026
    Atualizado por: Leonardo Matheus Talarico

    Descrição atualização: (Data, Atualizado por, Descrição, git)

    12/08/2026 João Henrique Cavalheiro Grillo: Foi incrementado a regra de bloqueios utilizada no itau espelhando a regra da procedure de projetos.

    18/08/2026 Leonardo Matheus Talarico: Foi modificado a forma como as devoluções são carregadas, desconsiderando totalmente informações da base 
    que possuem informações de retirada e foi introduzido nas linhas de insert da devolução o Set que verifica a quantidade de LinhasOrigens das 
    Devoluções para que possa entrar seus valores nas informações de Log
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

--/* Inicia o controle de logs */
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

--- | Ocorrências devoluções

If Object_id(N'Tempdb..#OcorrenciasDevolucoes') Is not null Drop table #OcorrenciasDevolucoes;
Create table #OcorrenciasDevolucoes (
    IdCarteira smallint,
    IdDevedor int,
    Complemento varchar(256)
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
        Convert(date, a.DataDevolucao) = Convert(date, Dateadd(hour,-3,Getdate()-1))
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
                    and a.IdDevedor = b.IdDevedor)
    and Exists (Select 1
                From misitau.dbo.Mailing c With(nolock)
                Where 
                    a.IdCarteira = c.IdCarteira
                    and a.IdDevedor = c.IdDevedor
                    and c.IdRetirada is null);

Set @LinhasOrigem = @@RowCount;

--- | Ocorrências

With OcorrenciasCTE as (
    Select distinct
        b.IdCarteira,
        a.IdDevedor,
        'Colchão' as Complemento
    From misitau.oco.Ocorrencias a
    Inner join misitau.cob.Titulos b on a.IdTitulo = b.IdTitulo
    Where
        a.DataOcorrencia = Convert(date, Dateadd(hour,-3,Getdate()-1))
        and a.IdTipoOcorrencia = 350
        and b.IdProduto = 9
    union
    Select distinct
        Convert(int,null) as IdCarteira,
        IdDevedor,
        Complemento
    From misitau.oco.Ocorrencias a
    Where
        DataOcorrencia > Convert(date, Dateadd(hour,-3,Getdate()-1))
        and IdTipoOcorrencia in (350)
    union
    Select distinct
        Convert(int,null) as IdCarteira,
        a.IdDevedor,
        'Remessa' as Complemento
    From misitau.cli.PromessaPagamento a
    Where
        a.DataVencimento > Convert(date, Dateadd(hour,-3,Getdate()-1))
)

Insert into #OcorrenciasDevolucoes (
                                    IdCarteira,
                                    IdDevedor,
                                    Complemento
                                    )
Select
    IdCarteira,
    IdDevedor,
    Complemento
From OcorrenciasCTE;

Insert into #Devolucoes (
                        IdCarteira,
                        IdDevedor
                        )
Select
    IdCarteira,
    IdDevedor
From #OcorrenciasDevolucoes a
Where
    (Complemento in ('Colchão','Remessa')
    or Complemento like '%BAIXA PGTO DO / DT PGTO%')
    and Exists (Select 1
                From misitau.dbo.Mailing c With(nolock)
                Where
                    a.IdCarteira = c.IdCarteira
                    and a.IdDevedor = c.IdDevedor
                    and c.IdRetirada is null);

Set @LinhasOrigem += @@RowCount;

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

Set @LinhasOrigem += @@RowCount;

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
                Isnull(a.IdCarteira,b.IdCarteira) = b.IdCarteira
                and a.IdDevedor = b.IdDevedor);

Set @LinhasAtualizadas = @@RowCount;

If Datepart(hour,@DataHoraInicio) < 8
Begin

	Update a
	Set a.IdRetirada = 2
	From misitau.dbo.Mailing a
	Where
		IdRetirada is null
		and Not Exists (Select 1
						From #DadosOrigem b
						Where
							Isnull(a.IdCarteira,b.IdCarteira) = b.IdCarteira
							and a.IdDevedor = b.IdDevedor);

end;

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