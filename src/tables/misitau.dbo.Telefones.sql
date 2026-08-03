Create table misitau.dbo.Telefones (
	IdTelefone int constraint PkTelefones primary key clustered,
	IdDevedor int,
	IdOrigem int,
	IdQualificacao int,
	IdPropriedade int,
	DDD char(2),
	Numero char(9),
	Pontuacao decimal,
	DataInclusao datetime,
	DataAtualizacao datetime
);

