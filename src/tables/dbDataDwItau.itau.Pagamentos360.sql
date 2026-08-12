Create table dbDataDwItau.itau.Pagamentos360 (
	IdPagamento int identity constraint PkPagamentos Primary Key clustered,
	IdBase int,
	Data datetime,
	IdDevedor int,
	IdTitulo int,
	IdAcordo int,
	NumeroParcela int,
	ValorPago money,
	Valor money,
	Referencia varchar(32),
	TipoAcordo int,
	DataCancelamento datetime,
	IdOrigemAcordo char(1)
);