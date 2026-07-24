Create table misitau.dbo.OrigensLigacoes (
	IdOrigemLigacao	char(1) constraint PkOrigemLigacoes primary key clustered,
	OrigemLigacao varchar(32),
	CodigoReferencia varchar(8)
);
