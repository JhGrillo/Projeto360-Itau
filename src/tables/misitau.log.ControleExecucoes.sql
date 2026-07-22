Create table misitau.log.ControleExecucoes (
	IdExecucao int identity(1,1) constraint PKControleExecucoes primary key,
	NomeProcedure varchar(128),
	DataHoraInicio datetime,
	DataHoraFim datetime,
	TempoExecucaoSegundos decimal,
	StatusExecucao varchar(20)
);