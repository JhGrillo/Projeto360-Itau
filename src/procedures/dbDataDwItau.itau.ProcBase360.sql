Create or alter procedure itau.ProcBase360 as

------------------------------> Descrição da procedure

/*
    Padrão de escrita: PascalCase
    Nome: ProcBase360
    DataCriação: 06/08/2026
    Criado por: Leonardo Matheus Talarico
    DataAtualização:
    Atualizado por:

    Descrição atualização: (Data, Atualizado por, Descrição, git)
*/

------------------------------> Definições de variaveis e controles de ambiente

Set Nocount On;

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

Set @Etapa = 'Criacao das tabelas temporarias';

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
	AreaNegocio varchar(2),
	FaixaValor varchar(32)
);

------------------------------> Carga das tabelas temporarias

Set @Etapa = 'Carga das tabelas temporarias';

--- | Base360

Insert into #Base360 (
					Data,
					CodigoReferencia,
					Carteira,
					Produto,
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
					ValorRegularizacao,
					AreaNegocio
				   )
Select
	*
From openquery (misitau, '
Select
	Convert(date,Getdate()) as Data,
	CodigoReferencia,
	Carteira,
	Produto,
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
	ValorRegularizacao,
	AreaNegocio
From misitau.dbo.Base With(nolock);');

Set @LinhasOrigem = @@RowCount;

/* Atualização de dados
Obs: Esta etapa faz a carga das colunas que necessitam que um cálculo seja feito.
*/

--- | Subproduto

Update a
Set a.SubProduto = Case
						When a.AreaNegocio in ('02', '2', '11') then 'NCOR'
						When a.AreaNegocio in ('01', '1')		then 'BPF'
					end
From #Base360 a;

--- | Dias em atraso

Update a
Set a.DiasEmAtraso = Datediff(day,a.DataVencimento,Getdate())
From #Base360 a;

--- | Faixa de atraso

Update a
Set a.FaixaAtraso = Case 
						When a.SubProduto = 'NCOR' then
							Case
								When a.DiasEmAtraso <= 90	then '01. Menor que 91'
								When a.DiasEmAtraso <= 180	then '02. 91 a 180'
								When a.DiasEmAtraso <= 360	then '03. 181 a 360'
								When a.DiasEmAtraso <= 720	then '04. 361 a 720'
								When a.DiasEmAtraso <= 1200	then '05. 721 a 1200'
								When a.DiasEmAtraso <= 1500	then '06. 1201 a 1500'
								When a.DiasEmAtraso <= 1800	then '07. 1501 a 1800'
								When a.DiasEmAtraso <= 2300	then '08. 1801 a 2300'
								When a.DiasEmAtraso > 2300	then '09. Acima de 2300'
								else '00. Sem faixa'
							end
						When a.SubProduto = 'BPF' then
							Case
								When a.DiasEmAtraso < 5		then '00. Sem faixa'
								When a.DiasEmAtraso <= 30	then '01. 5 a 30'
								When a.DiasEmAtraso <= 60	then '02. 31 a 60'
								When a.DiasEmAtraso <= 90	then '03. 61 a 90'
								When a.DiasEmAtraso <= 180	then '04. 91 a 180'
								When a.DiasEmAtraso <= 360	then '05. 181 a 360'
								When a.DiasEmAtraso <= 720	then '06. 361 a 720'
								When a.DiasEmAtraso <= 1200	then '07. 721 a 1200'
								When a.DiasEmAtraso <= 1500	then '08. 1201 a 1500'
								When a.DiasEmAtraso <= 1800	then '09. 1501 a 1800'
								When a.DiasEmAtraso <= 2300	then '10. 1801 a 2300'
								When a.DiasEmAtraso > 2300	then '11. Acima de 2300'
								else '00. Sem faixa'
							end
						else '00. Sem faixa'
					end
From #Base360 a;

--- | Faixa de valor

Update a
Set a.FaixaValor = Case 
						When Coalesce(a.ValorRegularizacao, a.Risco) <= 500		then '01. 0 a 500'
						When Coalesce(a.ValorRegularizacao, a.Risco) <= 1000	then '02. 501 a 1000'
						When Coalesce(a.ValorRegularizacao, a.Risco) <= 2000	then '03. 1001 a 2000'
						When Coalesce(a.ValorRegularizacao, a.Risco) <= 5000	then '04. 2001 a 5000'
						When Coalesce(a.ValorRegularizacao, a.Risco) <= 7000	then '05. 5001 a 7000'
						When Coalesce(a.ValorRegularizacao, a.Risco) <= 20000	then '06. 7001 a 20000'
						When Coalesce(a.ValorRegularizacao, a.Risco) <= 80000	then '07. 20000 a 80000'
						When Coalesce(a.ValorRegularizacao, a.Risco) > 80000	then '08. Acima de 80000'
						else '00. Sem faixa'
					end
From #Base360 a;

/* Cria index não clusterizado */
Create nonclustered index IxBase on #Base360 (IdDevedor, IdTitulo, Data) ;

------------------------------> Persistencia final

Set @Etapa = 'Persistencia final';

--- | Tabela fisica

Insert into dbDataDwItau.itau.Base360 (
									   Data,
									   CodigoReferencia,
									   Carteira,
									   Produto,
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
									   ValorRegularizacao,
									   AreaNegocio
									   )
Select
	Data,
	CodigoReferencia,
	Carteira,
	Produto,
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
	ValorRegularizacao,
	AreaNegocio
From #Base360 a With(nolock)
Where
	Not exists (Select 1
				From dbDataDwItau.itau.Base360 b With(nolock)
				Where
					a.IdDevedor = b.IdDevedor
					and a.IdTitulo = b.IdTitulo
					and a.Data = b.Data);

Set @LinhasInseridas = @@RowCount;

------------------------------> Atualizacao de dados

Set @Etapa = 'Atualizacao de dados';

--- | Atualiza campos da tabela fisica

Update a
Set a.DiasEmAtraso = b.DiasEmAtraso,
	a.SaldoVencido = b.SaldoVencido,
	a.Risco = b.Risco,
	a.FaixaValor = b.FaixaValor
From dbDataDwItau.itau.Base360 a With(nolock)
inner join #Base360 b on a.IdDevedor = b.IdDevedor
					     and a.IdTitulo = b.IdTitulo
Where
	Isnull(a.NumeroParcela, '') <> Isnull(b.NumeroParcela,'')
	or Isnull(a.DataInclusao, '') <> Isnull(b.DataInclusao,'')
	or Isnull(a.DiasEmAtraso, '') <> Isnull(b.DiasEmAtraso, '')
	or Isnull(a.Risco, '') <> Isnull(b.Risco, '')
	or Isnull(a.SaldoVencido, '') <> Isnull(b.SaldoVencido, '')
	or Isnull(a.ValorRegularizacao, '') <> Isnull(b.ValorRegularizacao, '');

Set @LinhasAtualizadas = @@RowCount;
Set @LinhasTotaisDestino = @LinhasInseridas + @LinhasAtualizadas;
Set @DataHoraFim = Getdate();

/* Grava volumetria controles de log */
Exec dbDataDwItau.[log].ProcControles
    @TipoLog = 'Volumetria',
    @IdExecucao = @IdExecucao,
    @NomeTabelaOrigem = 'dbo.Base',
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