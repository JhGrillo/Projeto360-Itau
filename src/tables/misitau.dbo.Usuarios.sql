Create table misitau.dbo.Usuarios (
	IdUsuario int constraint PkUsuario primary key clustered ,
	Nome varchar(128),
	Referencia varchar(64),
	DataAdmissao datetime,
	DataDemissao datetime,
	DataAtualizacao datetime
);