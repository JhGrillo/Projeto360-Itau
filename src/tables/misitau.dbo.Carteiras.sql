Create table misitau.dbo.Carteiras (
    IdCarteira smallint constraint PkCarteira primary key,
    IdCliente smallint,
    CodigoReferencia smallint,
    Carteira varchar(64),
    RazaoSocial varchar(128)
);
