Create table dbo.Devedores (
	IdDevedor int constraint PkDevedores primary key,
	IdOrigem tinyint,
	CnpjCpf char(14),
	RG char(9),
	RazaoSocialNome varchar(128),
	DataInclusao datetime,
	IdUsuarioInclusao int,
	DataAtualizacao datetime,
	IdUsuarioAtualizacao int,
	DataExclusao datetime,
	IdUsuarioExclusao int,
	IdUltimoEnriquecimento int,
	Apelido varchar(64),
	ValidoDe datetime,
	ValidoAte datetime
);