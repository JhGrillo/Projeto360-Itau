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
	DataAtualizacao datetime,
	IdTipoTelefone tinyint,
	WhatsApp char(1),
	CPC char(1),
	DataUltimoCPC datetime,
	IdEnriquecimento int,
	IdFornecedor int
);

