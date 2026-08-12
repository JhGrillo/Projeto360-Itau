Create table dbDataDwItau.itau.Vencimentos360 (
	IdVencimento int identity constraint PkVencimentos primary key clustered,
	IdBase int,
	Data datetime,
	IdDevedor int,
	IdTitulo int,
	IdAcordo int,
	NumeroParcela int,
	Valor money,
	Referencia varchar(32),
	DataCancelamento datetime,
	IdOrigemAcordo char(1)
);