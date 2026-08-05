Create table dbDataDwItau.log.ControleExpurgo (
	IdControleExpurgo int identity(1,1) constraint PkControleExpurgo primary key,
	IdTabelaExpurgo int,
	NomeTabela varchar(64),
	DataExecucao datetime
);