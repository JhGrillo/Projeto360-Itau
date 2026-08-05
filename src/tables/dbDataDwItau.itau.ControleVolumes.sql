Create table dbDataDwItau.log.ControleVolumes (
	IdControleVolume int identity constraint PkControleVolumes primary key clustered,
	IdExecucao int,
	NomeTabelaOrigem varchar(128),
	NomeTabelaDestino varchar(128),
	LinhasOrigem int,
	LinhasInseridas int,
	LinhasAtualizadas int,
	LinhasTotaisDestino int,
	DataExecucao datetime
);