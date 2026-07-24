Create table misitau.dbo.Eventos (
    IdEvento int constraint PkEventos primary key, 
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