Create table dbDataDwItau.itau.BaseMailing360 (
	IdBaseMailing int identity(1,1) constraint PKBaseMailing primary key,
	IdBase int,
	Data datetime,
	IdDevedor int,
	IdTitulo int,
	IdRetirada int
);