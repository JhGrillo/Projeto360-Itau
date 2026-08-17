Create table dbDataDwItau.itau.Pagamentos360 (
	IdPagamento int identity constraint PkPagamentos Primary Key clustered,
	Data datetime,
	IdAcordo int,
	TipoAcordo varchar(32),
	IdDevedor int,
	IdTitulo int,
	Plano int,
	NumeroParcela int,
	ValorPago money,
	Referencia varchar(64),
	Proposta char(1),
	DataAprovacaoProposta datetime,
	StatusAcordo varchar(64),
	IdOrigemAcordo char(2)
);