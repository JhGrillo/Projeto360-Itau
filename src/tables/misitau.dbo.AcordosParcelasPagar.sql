Create table misitau.dbo.AcordosParcelasPagar (
    IdAcordoParcelaPagar int constraint PkAcordoPercelaPagar primary key,
    IdAcordo int,
    NumeroParcela tinyint,
    DataVencimento date,
    Valor money,
    DataPagamento date,
    ValorPago money
);