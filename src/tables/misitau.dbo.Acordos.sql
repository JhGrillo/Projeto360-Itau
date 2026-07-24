Create table misitau.dbo.Acordos (
	IdAcordo int constraint PkAcordos primary key clustered,
	IdTipoAcordo tinyint,
	IdDevedor int,
	Plano tinyint,
	IdNegociadorResponsavel int,
	DataInclusao datetime,
	IdUsuarioInclusao int,
	Proposta char(1),
	DataAprovacaoProposta datetime,
	IdStatusAcordo tinyint,
	CodigoAcordoCliente varchar(32),
	DataCancelamento datetime,
	IdUsuarioCancelamento int
);