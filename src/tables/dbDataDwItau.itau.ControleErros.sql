Create table dbDataDwItau.log.ControleErros (
	IdErro int identity constraint PkControleErros primary key clustered,
	IdExecucao int,
	NomeProcedure varchar,
	DataErro datetime,
	MensagemErro varchar,
	NumeroErro int,
	LinhaErro int,
	EtapaErro varchar
);