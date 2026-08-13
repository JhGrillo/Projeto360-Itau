Create table dbDataDwItau.itau.CRM360 (
    IdCRM int identity(1,1) constraint PKCRM primary key,
	IdBase int,
	Data datetime,
	IdDevedor int,
	IdTitulo int,
	CodigoOcorrencia varchar(32),
	TipoOcorrencia varchar(64),
	IdLigacao int,
	IdOrigemLigacao char(2),
	DDD char(2),
	Numero char(9),
	Chave varchar(256),
	IdAcordo int,
	Referencia varchar(64),
	Atendimento int,
	CPC int,
	Acordo int
);