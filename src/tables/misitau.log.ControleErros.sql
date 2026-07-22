Create table misitau.log.ControleErros (
	IdErro int identity(1,1) constraint PK_ControleErros primary key,
	IdExecucao int,
	NomeProcedure varchar(128),
	DataErro datetime,
	MensagemErro varchar(max),
	NumeroErro int,
	LinhaErro int,
	EtapaErro varchar(100)
);