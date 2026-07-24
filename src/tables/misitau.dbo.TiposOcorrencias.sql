Create table misitau.dbo.TiposOcorrencias (
	IdTipoOcorrencia smallint constraint PkTipoOcorrencia primary key,
	IdTipoOcorrenciaReferencia smallint,
	IdSegmentacao char(1),
	CodigoOcorrencia varchar(32),
	TipoOcorrencia varchar(64),
	Agendamento char(1),
	DataComplementar char(1),
	ExigeComplemento char(1),
	Sistema char(1),
	IdClassificacao tinyint
);