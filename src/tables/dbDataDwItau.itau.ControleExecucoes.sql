Create table dbDataDwItau.log.ControleExecucoes (
	IdExecucao int identity constraint PkControleExecucoes primary key clustered,
	NomeProcedure varchar(128),
	DataHoraInicio datetime,
	DataHoraFim	datetime,
	TempoExecucaoSegundos decimal,
	StatusExecucao varchar(20)
);