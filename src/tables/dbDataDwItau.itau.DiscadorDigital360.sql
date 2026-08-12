Create table dbDataDwItau.itau.DiscadorDigital360 (
	IdDiscadorDigital int identity(1,1) constraint PKDiscadorDigital primary key,
	IdBase int,
	Data datetime,
	CodigoReferencia smallint,
	IdDevedor int,
	IdTitulo int,
	DDD char(2),
	Numero char(9),
	Origem varchar(20),
	Classificacao varchar(32),
	MotivoFinalizacao varchar(256),
	Referencia varchar(32),
	Campanha varchar(56),
	DuracaoChamada int,
	Chave varchar(256)
);