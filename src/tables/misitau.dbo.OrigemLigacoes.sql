Create table misitau.dbo.OrigemLigacoes (
	IdOrigemLigacao	char(1) constraint PkOrigemLigacoes primary key clustered,
	OrigemLigacao varchar(32),
	CodigoReferencia varchar(8)
);
