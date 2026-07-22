Create table log.TabelasControleExpurgo (
	IdTabelaExpurgo int identity(1,1) constraint PkTabelasControleExpurgo primary key,
	NomeTabela varchar(64),
	HoraExpurgo time
);