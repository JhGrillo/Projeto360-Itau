Create or Alter Procedure [dbo].[ProcTemporariaJoao] as

------------------------------> Descrição da procedure

/*
    Padrão de escrita: PascalCase
    Nome: ProcFunilDia360
    DataCriação: 21/08/2026
    Criado por: João Henrique Cavalheiro Grillo
    DataAtualização: 07/10/2026
    Atualizado por: João Henrique Cavalheiro Grillo

    Descrição atualização: (Data, Atualizado por, Descrição, git)
	
	07/10/2026 João Henrique Cavalheiro Grillo:
		- Campos / Métricas: Incluído valor de acordo, vencimento e pagamento da 1ª parcela para suporte às análises de WO (valor de regularização) e Ativo (1ª Parcela e Regularização).
*/

------------------------------> Definições de variaveis e controles de ambiente

Set Nocount On;

Declare @NomeProcedure varchar(128) = 'ProcFunilDia360',
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
        @LinhaErro int,
		@DataIni datetime,
		@DataFim datetime;

--/* Inicia o controle de logs */
Exec dbDataDwItau.[log].ProcControles
    @TipoLog = 'Execucao',
    @NomeProcedure = @NomeProcedure,
    @DataHoraInicio = @DataHoraInicio,
    @StatusExecucao = 'Executando',
    @IdExecucao = @IdExecucao OUTPUT;

Begin Try

------------------------------> Limpeza de tabela

Set @Etapa = 'Limpeza de tabela';

--- | Limpeza da tabela pelo periodo de analitico disponivel

Select
	@DataIni = Min(Data),
	@DataFim = Max(Data)
From dbDataDwItau.itau.AnaliticoFunilDia360 With(nolock);

Delete 
from dbDataDwItau.itau.FunilDia360
Where
	Data between @DataIni and @DataFim;

------------------------------> Persistencia final

Set @Etapa = 'Persistencia final';

--- | Tabela fisica

Insert into dbDataDwItau.itau.FunilDia360 (
										Data,
										CodigoReferencia,
										Carteira,
										Produto,
										SubProduto,
										Cluster,
										Mailing,
										FaixaAtraso,
										FaixaValor,
										Base,
										ValorRegularizacao,
										DiscagensDiscador,
										DiscagensDigital,
										Trabalhado,
										Atendido,
										CPC,
										Acordo,
										ValorAcordo,
										ValorAcordoRegularizacao,
										Vencimento,
										ValorVencimento,
										ValorVencimentoRegularizacao,
										Pagamento,
										ValorPagamento,
										ValorPagamentoRegularizacao
										)
Select
	Data,
	CodigoReferencia,
	Carteira,
	Produto,
	SubProduto,
	Cluster,
	Mailing,
	FaixaAtraso,
	FaixaValor,
	Count(IdDevedor) as Base,
	Sum(ValorRegularizacao) as ValorRegularizacao,
	Sum(DiscagensDiscador) as DiscagensDiscador,
	Sum(DiscagensDigital) as DiscagensDigital,
	Sum(Trabalhado) as Trabalhado,
	Sum(Atendido) as Atendido,
	Sum(CPC) as CPC,
	Sum(Acordo) as Acordo,
	Sum(ValorAcordo) as ValorAcordo,
	Sum(ValorAcordoRegularizacao) as ValorAcordoRegularizacao,
	Sum(Vencimento) as Vencimento,
	Sum(ValorVencimento) as ValorVencimento,
	Sum(ValorVencimentoRegularizacao) as ValorVencimentoRegularizacao,
	Sum(Pagamento) as Pagamento,
	Sum(ValorPagamento) as ValorPagamento,
	Sum(ValorPagamentoRegularizacao) as ValorPagamentoRegularizacao
From dbDataDwItau.itau.AnaliticoFunilDia360 With(nolock)
Group by
	Data,
	CodigoReferencia,
	Carteira,
	Produto,
	SubProduto,
	Cluster,
	Mailing,
	FaixaAtraso,
	FaixaValor;

Set @LinhasInseridas = @@RowCount;
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