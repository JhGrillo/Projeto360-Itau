Create table dbDataDwItau.itau.Vencimentos360 (
	IdVencimento int identity(1,1) constraint PKVencimentos360 primary key,
	IdBase int,
	Data datetime,
	IdAcordo int,
	TipoAcordo varchar(32),
	IdDevedor int,
	IdTitulo int,
	Plano int,
	NumeroParcela int,
	Valor money,
	Referencia varchar(64),
	Proposta char(1),
	DataAprovacaoProposta datetime,
	StatusAcordo varchar(64),
	DataCancelamento datetime,
	IdOrigemAcordo char(2)
);