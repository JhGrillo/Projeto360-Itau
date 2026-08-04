Create or Alter procedure [dbo].[ProcBase] as

------------------------------> Descrição da procedure

/*
    Padrão de escrita: PascalCase
    Nome: ProcBase
    DataCriação: 04/08/2026
    Criado por: João Henrique Cavalheiro Grillo
    DataAtualização:
    Atualizado por:

    Descrição atualização: (Data, Atualizado por, Descrição, git)
*/

------------------------------> Definições de variaveis e controles de ambiente

Set Nocount On;

Declare @NomeProcedure varchar(128) = 'ProcBase',
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

------------------------------> Criacao das tabelas temporarias

Set @Etapa = 'Criacao das tabelas temporarias';

--- | Parcelas

If Object_id('Tempdb..#Parcelas') Is not null Drop table #Parcelas;
Create table #Parcelas (
    IdTitulo int constraint PkPacelas primary key,
    NumeroParcela int,
    ValorPrincipal money,
    Risco money,
    SaldoVencido money,
    DataVencimento datetime,
    DataInclusao datetime,
    DataReabertura datetime
);

--- | Titulos

If Object_id('Tempdb..#Titulos') Is not null Drop table #Titulos;
Create table #Titulos (
    IdTitulo int constraint PkTitulos primary key,
    NumeroContrato varchar(32),
    IdDevedor int,
    IdCarteira smallint,
    IdProduto smallint,
    Plano smallint,
    ValorContratoAtualizado money,
    AreaNegocio varchar(2),
    CodigoClusterScore varchar(4)
);

--- | Devedores titulos

If Object_id('Tempdb..#DevedoresTitulos') Is not null Drop table #DevedoresTitulos;
Create table #DevedoresTitulos (
    IdDevedor int constraint PkDevedoresTitulo primary key
);

--- | Devedores

If Object_id('Tempdb..#Devedores') Is not null Drop table #Devedores;
Create table #Devedores (
    IdDevedor int constraint PkDevedores primary key,
    CnpjCpf varchar(14),
    RazaoSocialNome varchar(128)
);

--- | Carteiras

If Object_id('Tempdb..#Carteiras') Is not null Drop table #Carteiras;
Create table #Carteiras (
    IdCarteira smallint constraint PkCarteira primary key,
    CodigoReferencia smallint,
    Carteira varchar(64)
);

--- | Produtos

If Object_id('Tempdb..#Produtos') Is not null Drop table #Produtos;
Create table #Produtos (
    IdProduto smallint constraint PkProdutos primary key,
    Produto varchar(64)
);

--- | Escob

If Object_id('Tempdb..#Escob') Is not null Drop table #Escob;
Create table #Escob (
    IdTitulo int constraint PkEscob primary key,
    Cluster varchar(4)
);

--- | Propensao

If Object_id('Tempdb..#Propensao') Is not null Drop table #Propensao;
Create table #Propensao (
    IdTitulo int constraint PkPropensao primary key,
    Cluster varchar(4)
);
 
--- | Extrato

If Object_id('Tempdb..#Base') Is not null Drop table #Base;
Create table #Base (
    CodigoReferencia smallint,
    Carteira varchar(64),
    Produto varchar(64),
    SubProduto varchar(10),
    Cluster varchar(4),
    IdDevedor int,
    CnpjCpf varchar(14),
    IdTitulo int,
    NumeroContrato varchar(32),
    RazaoSocialNome varchar(128),
    Plano smallint,
    NumeroParcela smallint,
    DataInclusao datetime,
    DataVencimento datetime,
    DiasEmAtraso int,
    FaixaAtraso varchar(32),
    Risco money,
    SaldoVencido money,
    ValorRegularizacao money,
    FaixaValor varchar(32)
);

------------------------------> Carga das tabelas temporarias

Set @Etapa = 'Carga das tabelas temporarias';

--- | Parcelas

Insert into #Parcelas (
                      IdTitulo,
                      NumeroParcela,
                      ValorPrincipal,
                      Risco,
                      SaldoVencido,
                      DataVencimento,
                      DataInclusao,
                      DataReabertura
                    )
Select
	a.IdTitulo,
	Min(a.NumeroParcela) as NumeroParcela,
	Min(a.ValorPrincipal) as ValorPrincipal,
	Sum(a.ValorPrincipal) as Risco,
	Sum(Case when a.DataVencimento < Convert(date,Convert(date,Dateadd(hour,-3,Getdate()))) then a.ValorPrincipal end) as SaldoVencido,
	Min(a.DataVencimento) as DataVencimento,
	Max(a.DataInclusao) as DataInclusao,
    Max(b.DataReabertura) as DataReabertura
From misitau.dbo.Parcelas a With(nolock)
Left join misitau.dbo.ParcelasInformacoesComplementares b With(nolock) on a.IdParcela = b.IdParcela
Where
	a.IdSituacaoParcela = 'A'
Group by
	a.IdTitulo;

--- | Titulos

Insert into #Titulos (
                     IdTitulo,
                     NumeroContrato,
                     IdDevedor,
                     IdCarteira,
                     IdProduto,
                     Plano,
                     ValorContratoAtualizado,
                     AreaNegocio,
                     CodigoClusterScore
                    )
Select
	a.IdTitulo,
    a.NumeroContrato,
	a.IdDevedor,
	a.IdCarteira,
	a.IdProduto,
	a.Plano,
	b.ValorContratoAtualizado,
    b.AreaNegocio,
    b.CodigoClusterScore
From misitau.dbo.Titulos a With(nolock)
Left join misitau.dbo.TitulosInformacoesComplementares b With(nolock) on a.IdTitulo = b.IdTitulo
Inner join #Parcelas c on a.IdTitulo = c.IdTitulo;

--- | Devedores titulos

Insert into #DevedoresTitulos (
                                IdDevedor
                               )
Select distinct
    IdDevedor
From #Titulos;

--- | Devedores

Insert into #Devedores (
                        IdDevedor,
                        CnpjCpf,
                        RazaoSocialNome
                    )
Select
    a.IdDevedor,
    CnpjCpf,
    RazaoSocialNome
From misitau.dbo.Devedores a With(nolock)
Inner join #DevedoresTitulos b on a.IdDevedor = b.IdDevedor;

--- | Carteiras

Insert into #Carteiras (
                       IdCarteira,
                       CodigoReferencia,
                       Carteira
                       )
Select
    IdCarteira,
    CodigoReferencia,
    Carteira
From misitau.dbo.Carteiras With(nolock);

--- | Produtos

Insert into #Produtos (
                       IdProduto,
                       Produto
                    )
Select
    IdProduto,
    Produto
From misitau.dbo.Produtos With(nolock);

--- | Escob

Insert into #Escob (
                    IdTitulo,
                    Cluster
                )
Select
    a.IdTitulo,
    Cluster
From misitau.dbo.Escob a With(nolock)
Inner join #Parcelas b on a.IdTitulo = b.IdTitulo;

--- | Propensao

Insert into #Propensao (
                        IdTitulo,
                        Cluster
                    )
Select
    a.IdTitulo,
    Cluster
From misitau.dbo.Propensao a With(nolock)
Inner join #Parcelas b on a.IdTitulo = b.IdTitulo;

--- | Extrato

Insert into #Base (
                CodigoReferencia,
                Carteira,
                Produto,
                SubProduto,
                Cluster,
                IdDevedor,
                CnpjCpf,
                IdTitulo,
                NumeroContrato,
                RazaoSocialNome,
                Plano,
                NumeroParcela,
                DataInclusao,
                DataVencimento,
                DiasEmAtraso,
                FaixaAtraso,
                Risco,
                SaldoVencido,
                ValorRegularizacao,
                FaixaValor
                )
Select
    d.CodigoReferencia,
    d.Carteira,
    e.Produto,
    Calc.SubProduto,
    Case 
        when Coalesce(b.CodigoClusterScore, esc.Cluster, prop.Cluster) In ('A0', 'A00')				 Then 'A0'
        when Coalesce(b.CodigoClusterScore, esc.Cluster, prop.Cluster) In ('A1', 'A01')				 Then 'A1'
        when Coalesce(b.CodigoClusterScore, esc.Cluster, prop.Cluster) In ('A2', 'A02')				 Then 'A2'
        when Coalesce(b.CodigoClusterScore, esc.Cluster, prop.Cluster) In ('A3', 'A03', 'A04', 'A4') Then 'A3'
        when Coalesce(b.CodigoClusterScore, esc.Cluster, prop.Cluster) In ('W1', 'W01')				 Then 'W1'
        when Coalesce(b.CodigoClusterScore, esc.Cluster, prop.Cluster) In ('W2', 'W02')				 Then 'W2'
        when Coalesce(b.CodigoClusterScore, esc.Cluster, prop.Cluster) In ('W3', 'W03')				 Then 'W3'
        when Coalesce(b.CodigoClusterScore, esc.Cluster, prop.Cluster) In ('W4', 'W04')				 Then 'W4' 
    end as Cluster,
    c.IdDevedor,
    c.CnpjCpf,
    b.IdTitulo,
    b.NumeroContrato,
    c.RazaoSocialNome,
    b.Plano,
    a.NumeroParcela,
    Coalesce(a.DataReabertura, a.DataInclusao) as DataInclusao,
    a.DataVencimento,
    Calc.DiasEmAtraso,
    Case 
        when Calc.SubProduto = 'NCOR' then
            Case
                when Calc.DiasEmAtraso <= 90   then '01.Menor que 91'
                when Calc.DiasEmAtraso <= 180  then '02.91 a 180'
                when Calc.DiasEmAtraso <= 360  then '03.181 a 360'
                when Calc.DiasEmAtraso <= 720  then '04.361 a 720'
                when Calc.DiasEmAtraso <= 1200 then '05.721 a 1200'
                when Calc.DiasEmAtraso <= 1500 then '06.1201 a 1500'
                when Calc.DiasEmAtraso <= 1800 then '07.1501 a 1800'
                when Calc.DiasEmAtraso <= 2300 then '08.1801 a 2300'
                when Calc.DiasEmAtraso > 2300  then '09.Acima de 2300'
                else '00.Sem faixa'
            end
        when Calc.SubProduto = 'BFP' then
            Case
                when Calc.DiasEmAtraso < 5     then '00.Sem faixa'
                when Calc.DiasEmAtraso <= 30   then '01.5 a 30'
                when Calc.DiasEmAtraso <= 60   then '02.31 a 60'
                when Calc.DiasEmAtraso <= 90   then '03.61 a 90'
                when Calc.DiasEmAtraso <= 180  then '04.91 a 180'
                when Calc.DiasEmAtraso <= 360  then '05.181 a 360'
                when Calc.DiasEmAtraso <= 720  then '06.361 a 720'
                when Calc.DiasEmAtraso <= 1200 then '07.721 a 1200'
                when Calc.DiasEmAtraso <= 1500 then '08.1201 a 1500'
                when Calc.DiasEmAtraso <= 1800 then '09.1501 a 1800'
                when Calc.DiasEmAtraso <= 2300 then '10.1801 a 2300'
                when Calc.DiasEmAtraso > 2300  then '11.Acima de 2300'
                else '00.Sem faixa'
            end
        else '00.Sem faixa'
    end as FaixaAtraso,
    a.Risco,
    a.SaldoVencido,
    b.ValorContratoAtualizado as ValorRegularizacao,
    Case
        when Coalesce(b.ValorContratoAtualizado,a.Risco) <= 500   then '01.0 a 500'
        when Coalesce(b.ValorContratoAtualizado,a.Risco) <= 1000  then '02.501 a 1000'
        when Coalesce(b.ValorContratoAtualizado,a.Risco) <= 2000  then '03.1001 a 2000'
        when Coalesce(b.ValorContratoAtualizado,a.Risco) <= 5000  then '04.2001 a 5000'
        when Coalesce(b.ValorContratoAtualizado,a.Risco) <= 7000  then '05.5001 a 7000'
        when Coalesce(b.ValorContratoAtualizado,a.Risco) <= 20000 then '06.7001 a 20000'
        when Coalesce(b.ValorContratoAtualizado,a.Risco) <= 80000 then '07.20001 a 80000'
        when Coalesce(b.ValorContratoAtualizado,a.Risco) > 80000  then '08.Acima de 80000'
        else '00.Sem faixa'
    end as FaixaValor
From #Parcelas a
Inner join #Titulos b on a.IdTitulo = b.IdTitulo
Inner join #Devedores c on b.IdDevedor = c.IdDevedor
Inner join #Carteiras d on b.IdCarteira = d.IdCarteira
Inner join #Produtos e on b.IdProduto = e.IdProduto
Left join #Escob esc on a.IdTitulo = esc.IdTitulo
Left join #Propensao prop on a.IdTitulo = prop.IdTitulo
Cross Apply (Select 
                Datediff(day,a.DataVencimento,Convert(date,Dateadd(hour,-3,Getdate()))) as DiasEmAtraso,
                Case
                    when b.AreaNegocio in ('02','2','11') then 'NCOR'
                    when b.AreaNegocio in ('01','1')    then 'BFP'
                end as SubProduto) Calc;

------------------------------> Persistencia final

Set @Etapa = 'Persistencia final';

--- | Tabela fisica

Truncate table misitau.dbo.Base;
Insert into misitau.dbo.Base (
                            CodigoReferencia,
                            Carteira,
                            Produto,
                            SubProduto,
                            Cluster,
                            IdDevedor,
                            CnpjCpf,
                            IdTitulo,
                            NumeroContrato,
                            RazaoSocialNome,
                            Plano,
                            NumeroParcela,
                            DataInclusao,
                            DataVencimento,
                            DiasEmAtraso,
                            FaixaAtraso,
                            Risco,
                            SaldoVencido,
                            ValorRegularizacao,
                            FaixaValor
                            )
Select
    CodigoReferencia,
    Carteira,
    Produto,
    SubProduto,
    Cluster,
    IdDevedor,
    CnpjCpf,
    IdTitulo,
    NumeroContrato,
    RazaoSocialNome,
    Plano,
    NumeroParcela,
    DataInclusao,
    DataVencimento,
    DiasEmAtraso,
    FaixaAtraso,
    Risco,
    SaldoVencido,
    ValorRegularizacao,
    FaixaValor
From #Base a;

Set @LinhasInseridas = @@RowCount;

------------------------------> Atualizacao de dados

Set @Etapa = 'Atualizacao de dados';

/* Grava volumetria controles de log */
Exec misitau.[log].ProcControles
    @TipoLog = 'Volumetria',
    @IdExecucao = @IdExecucao,
    @NomeTabelaDestino = 'dbo.Base',
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