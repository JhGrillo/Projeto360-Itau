Create table dbDataDwItau.itau.Acordos360 (
	IdAcordos int identity PkAcordos primary key clustered,
	IdBase int,
	Data datetime.
	IdDevedor int,
	IdTitulo int,
	Plano smallint,
	NumeroParcela smallint,
	Valor money,
	IdAcordo int,
	IdTipoAcordo smallint,
	DataInclusao datetime,
	Proposta char(1),
	DataAprovacaoProposta datetime,
	IdStatusAcordo int,
	DataCancelamento datetime,
	IdOrigemAcordo char,
	Referencia varchar(32)
);