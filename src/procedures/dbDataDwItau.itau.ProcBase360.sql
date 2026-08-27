Create or Alter Procedure itau.ProcBase360 as 

------------------------------> Descrição da procedure

/*
    Padrão de escrita: PascalCase
    Nome: ProcBase360
    DataCriação: 06/08/2026
    Criado por: Leonardo Matheus Talarico
    DataAtualização: 26/08/2026
    Atualizado por: Leonardo Matheus Talarico

    Descrição atualização: (Data, Atualizado por, Descrição, git)

	14/08/2026 João Henrique Cavalheiro Grillo: Refatorado o processo para melhoria de performance e elegibilidade de código, agora todas as tratativas são realizadas diretamento em cross aply,
	economizando o custo da consulta ao inves de realizar diversos updates ao longo da procedure.

	26/08/2026 Leonardo Matheus Talarico: Foi modificado a forma que é inserido as infromações na temporária #Base360, pois era contado em todos os processos a quantidade total de linhas de dentro da 
	misitau.dbo.Base, mas ao contabilizar as linhas inseridas ou atualizadas na tabela física, as informações eram diferentes, já que no primeiro processo todas as linhas já haviam sido inseridas
	o que faria que só houvesse mudanças nas suas atualizações que não acompanham as linhas de origem

*/

------------------------------> Definições de variaveis e controles de ambiente

Set Nocount on;

Declare @NomeProcedure varchar(128) = 'ProcBase360',
        @Etapa varchar(100) = 'Inicio',
        @IdExecucao int,
        @LinhasOrigem int,
        @LinhasInseridas int,
        @LinhasAtualizadas int,
        @LinhasTotaisDestino int,
        @DataHoraInicio datetime = Getdate(),
        @DataHoraFim datetime,
        @MensagemErro varchar(max),
        @NumeroErro int,
        @LinhaErro int;

/* Inicia o controle de logs */
Exec dbDataDwItau.[log].ProcControles
    @TipoLog = 'Execucao',
    @NomeProcedure = @NomeProcedure,
    @DataHoraInicio = @DataHoraInicio,
    @StatusExecucao = 'Executando',
    @IdExecucao = @IdExecucao OUTPUT;

Begin Try

------------------------------> Criacao de tabelas temporarias

Set @Etapa = 'Carga das tabelas temporarias';

--- | Base360
If Object_id('Tempdb..#Base360') Is not null Drop table #Base360;
Create table #Base360 (
	Data datetime,
	CodigoReferencia smallint,
	Carteira varchar(64),
	Produto varchar(64),
	SubProduto varchar(64),
	Cluster varchar(4),
	IdDevedor int,
	CnpjCpf varchar(14),
	IdTitulo int,
	NumeroContrato varchar(32),
	RazaoSocialNome varchar(128),
	Plano smallint,
	NumeroParcela smallint,
	DataInclusao datetime,
	DataVencimento datetime,
	DiasEmAtraso int,
	FaixaAtraso varchar(32),
	Risco money,
	SaldoVencido money,
	ValorRegularizacao money,
	FaixaValor varchar(32),
	IdRetirada int
);

--- | Base360

With  BaseCTE as (
Select
	Convert(date,Getdate()) as Data,
	CodigoReferencia,
	Carteira,
	Produto,
	SubProduto,
	Cluster,
	IdDevedor,
	CnpjCpf,
	IdTitulo,
	NumeroContrato,
	RazaoSocialNome,
	Plano,
	NumeroParcela,
	DataInclusao,
	DataVencimento,
	DiasEmAtraso,
	FaixaAtraso,
	Risco,
	SaldoVencido,
	ValorRegularizacao,
	FaixaValor
From misitau.misitau.dbo.Base a With(nolock)
Cross Apply (Select
				Case
					When AreaNegocio in ('02', '2', '11') then 'NCOR'
					When AreaNegocio in ('01', '1')		  then 'BPF'
				end as SubProduto,
				Datediff(day,DataVencimento, Getdate()) as DiasEmAtraso,
				Case 
					When Coalesce(ValorRegularizacao, Risco) <= 500		then '01. 0 a 500'
					When Coalesce(ValorRegularizacao, Risco) <= 1000	then '02. 501 a 1000'
					When Coalesce(ValorRegularizacao, Risco) <= 2000	then '03. 1001 a 2000'
					When Coalesce(ValorRegularizacao, Risco) <= 5000	then '04. 2001 a 5000'
					When Coalesce(ValorRegularizacao, Risco) <= 7000	then '05. 5001 a 7000'
					When Coalesce(ValorRegularizacao, Risco) <= 20000	then '06. 7001 a 20000'
					When Coalesce(ValorRegularizacao, Risco) <= 80000	then '07. 20000 a 80000'
					When Coalesce(ValorRegularizacao, Risco) > 80000	then '08. Acima de 80000'
					else '00. Sem faixa'
				end as FaixaValor
			) as CalculosA
Cross Apply (Select
				Case 
					When SubProduto = 'NCOR' then
						Case
							When DiasEmAtraso <= 90		then '01. Menor que 91'
							When DiasEmAtraso <= 180	then '02. 91 a 180'
							When DiasEmAtraso <= 360	then '03. 181 a 360'
							When DiasEmAtraso <= 720	then '04. 361 a 720'
							When DiasEmAtraso <= 1200	then '05. 721 a 1200'
							When DiasEmAtraso <= 1500	then '06. 1201 a 1500'
							When DiasEmAtraso <= 1800	then '07. 1501 a 1800'
							When DiasEmAtraso <= 2300	then '08. 1801 a 2300'
							When DiasEmAtraso > 2300	then '09. Acima de 2300'
							else '00. Sem faixa'
						end
					When SubProduto = 'BPF' then
						Case
							When DiasEmAtraso < 5		then '00. Sem faixa'
							When DiasEmAtraso <= 30		then '01. 5 a 30'
							When DiasEmAtraso <= 60		then '02. 31 a 60'
							When DiasEmAtraso <= 90		then '03. 61 a 90'
							When DiasEmAtraso <= 180	then '04. 91 a 180'
							When DiasEmAtraso <= 360	then '05. 181 a 360'
							When DiasEmAtraso <= 720	then '06. 361 a 720'
							When DiasEmAtraso <= 1200	then '07. 721 a 1200'
							When DiasEmAtraso <= 1500	then '08. 1201 a 1500'
							When DiasEmAtraso <= 1800	then '09. 1501 a 1800'
							When DiasEmAtraso <= 2300	then '10. 1801 a 2300'
							When DiasEmAtraso > 2300	then '11. Acima de 2300'
							else '00. Sem faixa'
						end
					else '00. Sem faixa'
				end as FaixaAtraso
			) as CalculosB
), 

NovaBaseCTE as (
	Select 
		a.Data,
		a.CodigoReferencia,
		a.Carteira,
		a.Produto,
		a.SubProduto,
		a.Cluster,
		a.IdDevedor,
		a.CnpjCpf,
		a.IdTitulo,
		a.NumeroContrato,
		a.RazaoSocialNome,
		a.Plano,
		a.NumeroParcela,
		a.DataInclusao,
		a.DataVencimento,
		a.DiasEmAtraso,
		a.FaixaAtraso,
		a.Risco,
		a.SaldoVencido,
		a.ValorRegularizacao,
		a.FaixaValor
	From BaseCTE a
	Where 
		Not Exists (Select 1
					From dbDataDwItau.itau.Base360 b With(nolock)
					Where
						a.IdDevedor = b.IdDevedor
						and a.IdTitulo = b.IdTitulo
						and a.Data = b.Data)

	Union 

	Select 
		a.Data,
		a.CodigoReferencia,
		a.Carteira,
		a.Produto,
		a.SubProduto,
		a.Cluster,
		a.IdDevedor,
		a.CnpjCpf,
		a.IdTitulo,
		a.NumeroContrato,
		a.RazaoSocialNome,
		a.Plano,
		a.NumeroParcela,
		a.DataInclusao,
		a.DataVencimento,
		a.DiasEmAtraso,
		a.FaixaAtraso,
		a.Risco,
		a.SaldoVencido,
		a.ValorRegularizacao,
		a.FaixaValor
	From BaseCTE a
	inner join dbDataDwItau.itau.Base360 b With(nolock) on a.IdDevedor = b.IdDevedor
														   and a.IdTitulo = b.IdTitulo
														   and a.Data = b.Data
														   
	Where 
		Isnull(a.NumeroParcela,'') <> Isnull(b.NumeroParcela,'')
		or Isnull(a.DataInclusao,'1900-01-01') <> Isnull(b.DataInclusao,'1900-01-01')
		or Isnull(a.DiasEmAtraso,-1) <> Isnull(b.DiasEmAtraso,-1)
		or Isnull(a.Risco,'') <> Isnull(b.Risco,'')
		or Isnull(a.SaldoVencido,'') <> Isnull(b.SaldoVencido,'')
		or Isnull(a.ValorRegularizacao,'') <> Isnull(b.ValorRegularizacao,'')
		
	Union
	
		Select
			a.Data,
			a.CodigoReferencia,
			a.Carteira,
			a.Produto,
			a.SubProduto,
			a.Cluster,
			a.IdDevedor,
			a.CnpjCpf,
			a.IdTitulo,
			a.NumeroContrato,
			a.RazaoSocialNome,
			a.Plano,
			a.NumeroParcela,
			a.DataInclusao,
			a.DataVencimento,
			a.DiasEmAtraso,
			a.FaixaAtraso,
			a.Risco,
			a.SaldoVencido,
			a.ValorRegularizacao,
			a.FaixaValor
		From dbDataDwItau.itau.Base360 a With(nolock)
		left join BaseCTE b on a.IdDevedor = b.IdDevedor
								and a.IdTitulo = b.IdTitulo
								and a.Data = b.Data
		Where
			a.Data >= Convert(date,Getdate())
			and b.IdDevedor is null
			and a.IdRetirada is null
)
Insert into #Base360 (
					Data,
					CodigoReferencia,
					Carteira,
					Produto,
					SubProduto,
					Cluster,
					IdDevedor,
					CnpjCpf,
					IdTitulo,
					NumeroContrato,
					RazaoSocialNome,
					Plano,
					NumeroParcela,
					DataInclusao,
					DataVencimento,
					DiasEmAtraso,
					FaixaAtraso,
					Risco,
					SaldoVencido,
					ValorRegularizacao,
					FaixaValor
				   )
Select
	a.Data,
		a.CodigoReferencia,
		a.Carteira,
		a.Produto,
		a.SubProduto,
		a.Cluster,
		a.IdDevedor,
		a.CnpjCpf,
		a.IdTitulo,
		a.NumeroContrato,
		a.RazaoSocialNome,
		a.Plano,
		a.NumeroParcela,
		a.DataInclusao,
		a.DataVencimento,
		a.DiasEmAtraso,
		a.FaixaAtraso,
		a.Risco,
		a.SaldoVencido,
		a.ValorRegularizacao,
		a.FaixaValor
From NovaBaseCTE a;

Set @LinhasOrigem = @@RowCount;

------------------------------> Criação de indices

Set @Etapa = 'Criacao de indices';

/* Cria index não clusterizado */
Create nonclustered index IxBase on #Base360 (IdDevedor, IdTitulo, Data);

------------------------------> Persistencia final

Set @Etapa = 'Persistencia final';

--- | Tabela fisica

Insert into dbDataDwItau.itau.Base360 (
									   Data,
									   CodigoReferencia,
									   Carteira,
									   Produto,
									   SubProduto,
									   Cluster,
									   IdDevedor,
									   CnpjCpf,
									   IdTitulo,
									   NumeroContrato,
									   RazaoSocialNome,
									   Plano,
									   NumeroParcela,
									   DataInclusao,
									   DataVencimento,
									   Risco,
									   SaldoVencido,
									   ValorRegularizacao
									   )
Select
	Data,
	CodigoReferencia,
	Carteira,
	Produto,
	SubProduto,
	Cluster,
	IdDevedor,
	CnpjCpf,
	IdTitulo,
	NumeroContrato,
	RazaoSocialNome,
	Plano,
	NumeroParcela,
	DataInclusao,
	DataVencimento,
	Risco,
	SaldoVencido,
	ValorRegularizacao
From #Base360 a With(nolock)
Where
	Not exists (Select 1
				From dbDataDwItau.itau.Base360 b With(nolock)
				Where
					a.IdDevedor = b.IdDevedor
					and a.IdTitulo = b.IdTitulo
					and a.Data = b.Data);

Set @LinhasInseridas = @@RowCount;

--- | Atualiza campos da tabela fisica

/* Atualiza campos que tiveram alterações em seu contrato */

Update a
Set a.Plano = b.Plano,
	a.NumeroParcela = b.NumeroParcela,
	a.DataInclusao = b.DataInclusao,
	a.DataVencimento = b.DataVencimento,
	a.DiasEmAtraso = b.DiasEmAtraso,
	a.FaixaAtraso = b.FaixaAtraso,
	a.Risco = b.Risco,
	a.SaldoVencido = b.SaldoVencido,
	a.ValorRegularizacao = b.ValorRegularizacao,
	a.FaixaValor = b.FaixaValor
From dbDataDwItau.itau.Base360 a With(nolock)
inner join #Base360 b on a.IdDevedor = b.IdDevedor
					     and a.IdTitulo = b.IdTitulo
						 and a.Data = b.Data
Where
	Isnull(a.NumeroParcela,'') <> Isnull(b.NumeroParcela,'')
	or Isnull(a.DataInclusao,'1900-01-01') <> Isnull(b.DataInclusao,'1900-01-01')
	or Isnull(a.DiasEmAtraso,-1) <> Isnull(b.DiasEmAtraso,-1)
	or Isnull(a.Risco,'') <> Isnull(b.Risco,'')
	or Isnull(a.SaldoVencido,'') <> Isnull(b.SaldoVencido,'')
	or Isnull(a.ValorRegularizacao,'') <> Isnull(b.ValorRegularizacao,'');

Set @LinhasAtualizadas = @@RowCount;

/* Marcação de contratos devolvidos/retirados */

Update a
Set a.IdRetirada = 1
From dbDataDwItau.itau.Base360 a With(nolock)
left join #Base360 b on a.IdDevedor = b.IdDevedor
					    and a.IdTitulo = b.IdTitulo
						and a.Data = b.Data
Where
	a.Data >= Convert(date,Getdate())
	and b.IdDevedor is null
	and a.IdRetirada is null;

Set @LinhasAtualizadas += @@RowCount;
Set @LinhasTotaisDestino = @LinhasInseridas + isnull(@LinhasAtualizadas, 0);
Set @DataHoraFim = Getdate();

/* Grava volumetria controles de log */
Exec dbDataDwItau.[log].ProcControles
    @TipoLog = 'Volumetria',
    @IdExecucao = @IdExecucao,
    @NomeTabelaDestino = 'dbo.Base360',
    @LinhasOrigem = @LinhasOrigem,
    @LinhasInseridas = @LinhasInseridas,
    @LinhasAtualizadas = @LinhasAtualizadas,
    @LinhasTotaisDestino = @LinhasTotaisDestino;

/* Finaliza execução controles de log concluido */
Exec dbDataDwItau.[log].ProcControles
    @TipoLog = 'Atualizacao',
    @IdExecucao = @IdExecucao,
    @DataHoraFim = @DataHoraFim,
    @StatusExecucao = 'Concluida';

End Try
Begin Catch

Set @MensagemErro = Error_message();
Set @NumeroErro = Error_number();
Set @LinhaErro = Error_line();

/* Finalizacao execução de log erro */
Set @DataHoraFim = Getdate();
Exec dbDataDwItau.[log].ProcControles
    @TipoLog = 'Atualizacao',
    @IdExecucao = @IdExecucao,
    @DataHoraFim = @DataHoraFim,
    @StatusExecucao = 'Erro';

/* Execução log erro */
Exec dbDataDwItau.[log].ProcControles
    @TipoLog = 'Erro',
    @IdExecucao = @IdExecucao,
    @NomeProcedure = @NomeProcedure,
    @MensagemErro = @MensagemErro,
    @NumeroErro = @NumeroErro,
    @LinhaErro = @LinhaErro,
    @EtapaErro = @Etapa;

End Catch;
