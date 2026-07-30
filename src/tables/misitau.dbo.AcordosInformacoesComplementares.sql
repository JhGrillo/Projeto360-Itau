Create table misitau.dbo.AcordosInformacoesComplementares (
	IdAcordo int constraint PkAcordosInformacoesComplementares primary key,
	DataEnvioProposta smalldatetime,
	ValorContraProposta money,
	PlanoContraProposta tinyint,
	DataVencimentoContraProposta date,
	DataRetorno smalldatetime,
	IdCampanhaCodigoBarra bigint,
	IdBoleto int,
	IdJornada varchar(24),
	IdSimulacao varchar(24),
	IdCondicaoGeral varchar(24),
	IdResumo varchar(24),
	CodigoAlcada smallint,
	CodigoBanco varchar(4),
	NumeroAgencia varchar(5),
	NumeroConta varchar(20)
);