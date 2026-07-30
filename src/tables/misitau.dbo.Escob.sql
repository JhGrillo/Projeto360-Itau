Create table misitau.dbo.Escob (
    IdEscob int constraint PkEscob primary key,
    IdDevedor int,
    IdTitulo int,
    Cluster varchar(10),
    DataAtualizacao datetime
);