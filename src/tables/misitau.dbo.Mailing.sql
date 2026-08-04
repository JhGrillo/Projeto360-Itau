Create table misitau.dbo.Mailing (
	IdDevedor int,
	IdCarteira int,
	IdRetirada int,
	Constraint PkMailing Primary Key Clustered (IdDevedor, IdCarteira) 
);