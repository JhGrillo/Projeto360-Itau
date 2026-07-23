Create table misitau.dbo.DevedoresInformacoesComplementares (
	IdDevedorInformacaoComplementar int constraint PkDevedoresInformacoesComplementares primary key,
	DataInclusao datetime,
	IdUsuarioInclusao int,
	DataAtualizacao datetime,
	IdUsuarioAtualizacao int,
	IdDevedor int,
	DataNascimento smalldatetime,
	SexoCliente char(1),
	ValidoDe datetime2,
	ValidoAte datetime2
);