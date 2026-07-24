Create table misitau.dbo.Ocorrencias (
	IdOcorrencia int constraint PkOcorrencias primary key,
	IdDevedor int,
	IdTitulo int,
	IdParcela int,
	IdTipoOcorrencia int,
	IdOrigeim int,
	IdLigacao int,
	DataOcorrencia datetime,
	DataComplementar datetime,
	Complemento varchar(max),
	DataInclusao datetime,
	IdUsuarioInclusao int,
	DataAtualizacao datetime,
	IdUsuarioAtualizacao int,
	IdAcordo int
);