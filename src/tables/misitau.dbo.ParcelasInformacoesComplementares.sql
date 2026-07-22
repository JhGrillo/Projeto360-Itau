Create table misitau.dbo.ParcelasInformacoesComplementares (
	IdParcelaInformacaoComplementar int constraint PkParcelasInformacoesComplementares primary key,
	DataInclusao datetime,
	IdUsuarioInclusao int,
	DataAtualizacao datetime,
	IdUsuarioAtualizacao int,
	IdParcela int,
	DataReabertura date,
	ValidoDe datetime2,
	ValidoAte datetime2
);