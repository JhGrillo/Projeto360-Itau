Create table misitau.log.ControleVolumes (
	IdControleVolume int identity(1,1) constraint PKControleVolumes primary key,
	IdExecucao int,
	NomeTabelaOrigem varchar(128),
	NomeTabelaDestino varchar(128),
	LinhasOrigem int,
	LinhasInseridas int,
	LinhasAtualizadas int,
	LinhasTotaisDestino int,
	DataExecucao datetime
);