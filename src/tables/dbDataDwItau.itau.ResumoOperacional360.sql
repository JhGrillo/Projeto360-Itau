Create table dbDataDwItau.itau.ResumoOperacional360 (
	Data date,
	Hora time,
	CodigoReferencia smallint,
	Carteira varchar(64),
	Produto	varchar(64),
	SubProduto varchar(64),
	Cluster varchar(4),
	FaixaAtraso	varchar(32),
	ValorRegularizacao money,
	FaixaValor varchar(32),
	Referencia varchar(64),
	Nome varchar(128),
	Atendimento int,
	CPC int,
	Acordo int,
	ValorAcordo money
);