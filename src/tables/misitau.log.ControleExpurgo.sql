Create table misitau.log.ControleExpurgo (
	IdControleExpurgo int identity(1,1) constraint PKControleExpurgo primary key,
	IdTabelaExpurgo	int,
	NomeTabela varchar(64),
	DataExecucao datetime
)