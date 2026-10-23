Create table dbDataDwItau.itau.EstratificacaoHistorico360 as (
    Data datetime,
    CodigoReferencia smallint,
    Carteira varchar(64),
    Produto varchar(64),
    SubProduto varchar(64),
    Cluster varchar(4),
    FaixaAtraso varchar(32),
    FaixaValor varchar(32),
    Base int,
    SaldoVencido money,
    ValorRegularizacao money
)