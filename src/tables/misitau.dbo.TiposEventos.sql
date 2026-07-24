Create table misitau.dbo.TiposEventos (
    IdTipoEvento smallint constraint PkTiposEventos primary key,
    IdTipoEventoReferencia smallint,
    IdSegmentacao char(1),
    CodigoEvento varchar(32),
    TipoEvento varchar(64),
    Agendamento char(1),
    DataComplementar char(1),
    ExigeComplemento char(1),
    Sistema char(1),
    IdClassificacao tinyint
);