Create table misitau.dbo.Propensao (
    IdPropensao int constraint PkPropensao primary key,
    IdTitulo int,
    Cluster varchar(12),
    DataAtualizacao datetime
);