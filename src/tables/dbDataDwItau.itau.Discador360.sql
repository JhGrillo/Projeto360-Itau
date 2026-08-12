Create table dbDataDwItau.itau.Discador360 (
	IdDiscador int identity(1,1) constraint PKDiscador360 primary key,
	IdBase int,
	Data datetime,
	IdDevedor int,
	IdTitulo int,
	DDD char(2),
	Numero char(9),
	Origem varchar(20),
	Classificacao varchar(32),
	MotivoFinalizacao varchar(256),
	Referencia varchar(32),
	Campanha varchar(56),
	TipoTelefone varchar(32),
	DuracaoChamada float,
	DuracaoFalado float,
	DuracaoTabulando float,
	Chave varchar(256)
);