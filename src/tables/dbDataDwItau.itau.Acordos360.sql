Create table dbDataDwItau.itau.Acordos360 (
	IdAcordos int identity(1,1) constraint PKAcordos360 primary key,
	IdBase int,
	IdAcordo int,
	TipoAcordo varchar(32),
	IdDevedor int,
	IdTitulo int,
	Plano int,
	NumeroParcela int,
	Valor money,
	Referencia varchar(64),
	DataInclusao datetime,
	Proposta char(1),
	DataAprovacaoProposta datetime,
	StatusAcordo varchar(64),
	DataCancelamento datetime,
	IdOrigemAcordo char(2)
);