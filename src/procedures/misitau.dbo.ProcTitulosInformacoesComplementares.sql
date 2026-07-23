Create or Alter Procedure dbo.ProcTitulosInformacoesComplementares as 

------------------------------> Descrição da procedure

/*
	Padrão de escrita: PascalCase
	Nome: ProcDevedores
	DataCriação: 23/07/2026
	Criado por: Leonardo Matheus Talarico
	DataAtualização:
	Atualizado por:

	Descrição atualização: (Data, Atualizado por, Descrição, git)
*/

------------------------------> Definições de variaveis e controles de ambiente

Set Nocount On;

Declare @NomeProcedure varchar(128) = 'ProcTitulosInformacoesComplementares',
        @Etapa varchar(100) = 'Inicio',
		@IdTituloInformacaoComplementar int,
		@UltimaAtualizacao datetime,
        @IdExecucao int,
        @LinhasOrigem int,
        @LinhasInseridas int,
        @LinhasAtualizadas int,
        @LinhasTotaisDestino int,
        @DataHoraInicio datetime = Dateadd(hour,-3,Getdate()),
        @DataHoraFim datetime,
        @MensagemErro varchar(max),
        @NumeroErro int,
        @LinhaErro int;


/* Inicia o controle de logs */
Exec misitau.[log].ProcControles
    @TipoLog = 'Execucao',
    @NomeProcedure = @NomeProcedure,
    @DataHoraInicio = @DataHoraInicio,
    @StatusExecucao = 'Executando',
    @IdExecucao = @IdExecucao OUTPUT;

Begin Try

------------------------------> Criacao de tabelas temporarias

Set @Etapa = 'Criacao das tabelas temporarias';

--- | Titulos informações complementares

If Object_id('Tempdb..#TitulosInformacoesComplementares') Is not null Drop table #TitulosInformacoesComplementares;
Create table #TitulosInformacoesComplementares (
	IdTituloInformacaoComplementar int,
	DataInclusao datetime,
	IdUsuarioInclusao int,
	DataAtualizacao datetime,
	IdUsuarioAtualizacao int,
	IdTitulo int,
	TipoContrato varchar(30),
	AgenciaPlataforma char(4),
	RegiaoPlataforma char(2),
	NumeroRecebimento char(12),
	DataContratacao smalldatetime,
	DataVencimentoContratoFatura smalldatetime,
	ValorContratoAtualizado money,
	QuantidadeParcelaAtraso tinyint,
	ValorContratoVencimento money,
	Empresa char(2),
	DataEnvioContrato smalldatetime,
	DataLimiteRetornoContrato smalldatetime,
	CodigoParecerEscritorioAnterior varchar(4),
	ParecerEscritorioAnterior1 varchar(68),
	ParecerEscritorioAnterior2 varchar(68),
	CodigoFilial varchar(5),
	ValorEncargosContrato money,
	CodigoEstrategia char(2),
	TarifaCobranca money,
	FaseCobranca char(2),
	CodigoSegurador char(3),
	CodigoOperacaoFinaustria varchar(4),
	NumeroContratoFinaustria varchar(12),
	CreditoImobiliarioSUSLIM char(1),
	EstrategiaIDSTG1 char(5),
	DataAtivacaoCobrancaConsorcio smalldatetime,
	NumeroCartao varchar(16),
	AgenciaContaCedenteDAC varchar(12),
	CodigoCarteira char(3),
	ValorAcordoPL money,
	CodigoOcorrenciaCobrancaJuridico varchar(5),
	CategoriaVeiculoCliente char(2),
	NumeroParcela char(3),
	IdTituloOriginal int,
	ContratoPiloto char(1),
	DataExclusao datetime,
	IdUsuarioExclusao int,
	ValidoDe datetime2,
	ValidoAte datetime2,
	ValorEntradaDiferenciada money,
	DataEntregaAmigavel date,
	DataUltimoAtraso datetime,
	DataVencimentoProximaParcela datetime,
	CodigoFamiliaProduto varchar(8),
	QuantidadeParcelasAbertoContrato varchar(8),
	QuantidadeParcelasPagas varchar(8),
	DataUltimoEnvioEmail datetime,
	DataUltimoEnvioPush datetime,
	DataUltimoEnvioSMS datetime,
	ValorMinimoFatura varchar(16),
	ValorSaldoTotalFatura varchar(16),
	QuantidadeDiasUtilizaLis varchar(8),
	ValorSaldoTotalFaturaSistema varchar(16),
	QuantParcelamentosFatura varchar(4),
	ValorReferenciaFatura varchar(16),
	ValorMinimoFaturaSistema varchar(16),
	DataUltimoPagamentoFatura datetime,
	CodigoEscritorioCobranca varchar(8),
	NomeProduto varchar(100),
	AreaNegocio varchar(2),
	QuantidadeDiasAtraso varchar(8),
	CodigoSubnivelCarteira varchar(16),
	CodigoClusterScore varchar(4),
	CodigoMotivoExclusao varchar(4),
	Origem varchar(8),
	CorrelationID varchar(100),
	ValorTotalRiscoVencido varchar(10),
	QuantidadeTotalParcelas varchar(10),
	ValorContratoNoVencimento varchar(10),
	TaxaJurosNominal varchar(10),
	CodigoRenavam varchar(16),
	IndicadorSaldoRemanescente varchar(10),
	DataVendaVeiculo varchar(10),
	DataApreensaoVeiculo varchar(10),
	IndicadorAcaoContra varchar(1),
	CodigoPlacaVeiculo varchar(10),
	AnoModeloVeiculo varchar(4),
	AnoFabricacaoVeiculo varchar(4),
	ModeloMarcaVeiculo varchar(256),
	DataVencimentoContrato varchar(10),
	DataUltimaParcelaConsig varchar(10),
	ValorUltimoPagamentoConsignado varchar(10),
	ValorSaldoDevedorContabil varchar(10)
);

------------------------------> Carga das tabelas temporarias

Set @Etapa = 'Carga das tabelas temporarias';

--- | Insere novos titulos na tabela

Set @IdTituloInformacaoComplementar = (Select Max(IdTituloInformacaoComplementar) From misitau.dbo.TitulosInformacoesComplementares With(nolock));
Set @UltimaAtualizacao = (Select 
							Case
								when Datepart(hour,Max(DataHoraInicio)) >= 22 then Max(Dateadd(day,+1,Convert(date,DataHoraInicio)))
								else Max(Convert(date,DataHoraInicio))
							end
                         From misitau.[log].ControleExecucoes
                         Where
                            NomeProcedure = 'ProcTitulosInformacoesComplementares'
                            and StatusExecucao = 'Concluida');

Insert into #TitulosInformacoesComplementares (
												IdTituloInformacaoComplementar,
												DataInclusao,
												IdUsuarioInclusao,
												DataAtualizacao,
												IdUsuarioAtualizacao,
												IdTitulo,
												TipoContrato,
												AgenciaPlataforma,
												RegiaoPlataforma,
												NumeroRecebimento,
												DataContratacao,
												DataVencimentoContratoFatura,
												ValorContratoAtualizado,
												QuantidadeParcelaAtraso,
												ValorContratoVencimento,
												Empresa,
												DataEnvioContrato,
												DataLimiteRetornoContrato,
												CodigoParecerEscritorioAnterior,
												ParecerEscritorioAnterior1,
												ParecerEscritorioAnterior2,
												CodigoFilial,
												ValorEncargosContrato,
												CodigoEstrategia,
												TarifaCobranca,
												FaseCobranca,
												CodigoSegurador,
												CodigoOperacaoFinaustria,
												NumeroContratoFinaustria,
												CreditoImobiliarioSUSLIM,
												EstrategiaIDSTG1,
												DataAtivacaoCobrancaConsorcio,
												NumeroCartao,
												AgenciaContaCedenteDAC,
												CodigoCarteira,
												ValorAcordoPL,
												CodigoOcorrenciaCobrancaJuridico,
												CategoriaVeiculoCliente,
												NumeroParcela,
												IdTituloOriginal,
												ContratoPiloto,
												DataExclusao,
												IdUsuarioExclusao,
												ValidoDe,
												ValidoAte,
												ValorEntradaDiferenciada,
												DataEntregaAmigavel,
												DataUltimoAtraso,
												DataVencimentoProximaParcela,
												CodigoFamiliaProduto,
												QuantidadeParcelasAbertoContrato,
												QuantidadeParcelasPagas,
												DataUltimoEnvioEmail,
												DataUltimoEnvioPush,
												DataUltimoEnvioSMS,
												ValorMinimoFatura,
												ValorSaldoTotalFatura,
												QuantidadeDiasUtilizaLis,
												ValorSaldoTotalFaturaSistema,
												QuantParcelamentosFatura,
												ValorReferenciaFatura,
												ValorMinimoFaturaSistema,
												DataUltimoPagamentoFatura,
												CodigoEscritorioCobranca,
												NomeProduto,
												AreaNegocio,
												QuantidadeDiasAtraso,
												CodigoSubnivelCarteira,
												CodigoClusterScore,
												CodigoMotivoExclusao,
												Origem,
												CorrelationID,
												ValorTotalRiscoVencido,
												QuantidadeTotalParcelas,
												ValorContratoNoVencimento,
												TaxaJurosNominal,
												CodigoRenavam,
												IndicadorSaldoRemanescente,
												DataVendaVeiculo,
												DataApreensaoVeiculo,
												IndicadorAcaoContra,
												CodigoPlacaVeiculo,
												AnoModeloVeiculo,
												AnoFabricacaoVeiculo,
												ModeloMarcaVeiculo,
												DataVencimentoContrato,
												DataUltimaParcelaConsig,
												ValorUltimoPagamentoConsignado,
												ValorSaldoDevedorContabil
											)
Select
	IdTituloInformacaoComplementar,
	DataInclusao,
	IdUsuarioInclusao,
	DataAtualizacao,
	IdUsuarioAtualizacao,
	IdTitulo,
	TipoContrato,
	AgenciaPlataforma,
	RegiaoPlataforma,
	NumeroRecebimento,
	DataContratacao,
	DataVencimentoContratoFatura,
	ValorContratoAtualizado,
	QuantidadeParcelaAtraso,
	ValorContratoVencimento,
	Empresa,
	DataEnvioContrato,
	DataLimiteRetornoContrato,
	CodigoParecerEscritorioAnterior,
	ParecerEscritorioAnterior1,
	ParecerEscritorioAnterior2,
	CodigoFilial,
	ValorEncargosContrato,
	CodigoEstrategia,
	TarifaCobranca,
	FaseCobranca,
	CodigoSegurador,
	CodigoOperacaoFinaustria,
	NumeroContratoFinaustria,
	CreditoImobiliarioSUSLIM,
	EstrategiaIDSTG1,
	DataAtivacaoCobrancaConsorcio,
	NumeroCartao,
	AgenciaContaCedenteDAC,
	CodigoCarteira,
	ValorAcordoPL,
	CodigoOcorrenciaCobrancaJuridico,
	CategoriaVeiculoCliente,
	NumeroParcela,
	IdTituloOriginal,
	ContratoPiloto,
	DataExclusao,
	IdUsuarioExclusao,
	ValidoDe,
	ValidoAte,
	ValorEntradaDiferenciada,
	DataEntregaAmigavel,
	DataUltimoAtraso,
	DataVencimentoProximaParcela,
	CodigoFamiliaProduto,
	QuantidadeParcelasAbertoContrato,
	QuantidadeParcelasPagas,
	DataUltimoEnvioEmail,
	DataUltimoEnvioPush,
	DataUltimoEnvioSMS,
	ValorMinimoFatura,
	ValorSaldoTotalFatura,
	QuantidadeDiasUtilizaLis,
	ValorSaldoTotalFaturaSistema,
	QuantParcelamentosFatura,
	ValorReferenciaFatura,
	ValorMinimoFaturaSistema,
	DataUltimoPagamentoFatura,
	CodigoEscritorioCobranca,
	NomeProduto,
	AreaNegocio,
	QuantidadeDiasAtraso,
	CodigoSubnivelCarteira,
	CodigoClusterScore,
	CodigoMotivoExclusao,
	Origem,
	CorrelationID,
	ValorTotalRiscoVencido,
	QuantidadeTotalParcelas,
	ValorContratoNoVencimento,
	TaxaJurosNominal,
	CodigoRenavam,
	IndicadorSaldoRemanescente,
	DataVendaVeiculo,
	DataApreensaoVeiculo,
	IndicadorAcaoContra,
	CodigoPlacaVeiculo,
	AnoModeloVeiculo,
	AnoFabricacaoVeiculo,
	ModeloMarcaVeiculo,
	DataVencimentoContrato,
	DataUltimaParcelaConsig,
	ValorUltimoPagamentoConsignado,
	ValorSaldoDevedorContabil
From misitau.cli.TitulosInformacoesComplementares a
Where
	(IdTituloInformacaoComplementar > Isnull(@IdTituloInformacaoComplementar,0)
	or DataAtualizacao >= @UltimaAtualizacao)
	and Not exists (Select 1
					From misitau.dbo.TitulosInformacoesComplementares b With(nolock)
					Where
						a.IdTituloInformacaoComplementar = b.IdTituloInformacaoComplementar
						and Isnull(a.DataAtualizacao,'1900-01-01') = Isnull(b.DataAtualizacao,'1900-01-01'));

--Set @LinhasOrigem = @@RowCount;

------------------------------> Criacao de índices

Set @Etapa = 'Criacao de indices';

/* Cria index não clusterizado */
Create nonclustered index IxTitulo on #TitulosInformacoesComplementares (IdTituloInformacaoComplementar);

------------------------------> Persistencia final

Set @Etapa = 'Persistencia final';

--- | Tabela fisica

Insert into mis.dbo.TitulosInformacoesComplementares (
													  IdTituloInformacaoComplementar,
													  DataInclusao,
													  IdUsuarioInclusao,
													  DataAtualizacao,
													  IdUsuarioAtualizacao,
													  IdTitulo,
													  TipoContrato,
													  AgenciaPlataforma,
													  RegiaoPlataforma,
													  NumeroRecebimento,
													  DataContratacao,
													  DataVencimentoContratoFatura,
													  ValorContratoAtualizado,
													  QuantidadeParcelaAtraso,
													  ValorContratoVencimento,
													  Empresa,
													  DataEnvioContrato,
													  DataLimiteRetornoContrato,
													  CodigoParecerEscritorioAnterior,
													  ParecerEscritorioAnterior1,
													  ParecerEscritorioAnterior2,
													  CodigoFilial,
													  ValorEncargosContrato,
													  CodigoEstrategia,
													  TarifaCobranca,
													  FaseCobranca,
													  CodigoSegurador,
													  CodigoOperacaoFinaustria,
													  NumeroContratoFinaustria,
													  CreditoImobiliarioSUSLIM,
													  EstrategiaIDSTG1,
													  DataAtivacaoCobrancaConsorcio,
													  NumeroCartao,
													  AgenciaContaCedenteDAC,
													  CodigoCarteira,
													  ValorAcordoPL,
													  CodigoOcorrenciaCobrancaJuridico,
													  CategoriaVeiculoCliente,
													  NumeroParcela,
													  IdTituloOriginal,
													  ContratoPiloto,
													  DataExclusao,
													  IdUsuarioExclusao,
													  ValidoDe,
													  ValidoAte,
													  ValorEntradaDiferenciada,
													  DataEntregaAmigavel,
													  DataUltimoAtraso,
													  DataVencimentoProximaParcela,
													  CodigoFamiliaProduto,
													  QuantidadeParcelasAbertoContrato,
													  QuantidadeParcelasPagas,
													  DataUltimoEnvioEmail,
													  DataUltimoEnvioPush,
													  DataUltimoEnvioSMS,
													  ValorMinimoFatura,
													  ValorSaldoTotalFatura,
													  QuantidadeDiasUtilizaLis,
													  ValorSaldoTotalFaturaSistema,
													  QuantParcelamentosFatura,
													  ValorReferenciaFatura,
													  ValorMinimoFaturaSistema,
													  DataUltimoPagamentoFatura,
													  CodigoEscritorioCobranca,
													  NomeProduto,
													  AreaNegocio,
													  QuantidadeDiasAtraso,
													  CodigoSubnivelCarteira,
													  CodigoClusterScore,
													  CodigoMotivoExclusao,
													  Origem,
													  CorrelationID,
													  ValorTotalRiscoVencido,
													  QuantidadeTotalParcelas,
													  ValorContratoNoVencimento,
													  TaxaJurosNominal,
													  CodigoRenavam,
													  IndicadorSaldoRemanescente,
													  DataVendaVeiculo,
													  DataApreensaoVeiculo,
													  IndicadorAcaoContra,
													  CodigoPlacaVeiculo,
													  AnoModeloVeiculo,
													  AnoFabricacaoVeiculo,
													  ModeloMarcaVeiculo,
													  DataVencimentoContrato,
													  DataUltimaParcelaConsig,
													  ValorUltimoPagamentoConsignado,
													  ValorSaldoDevedorContabil
												      )
Select distinct
	IdTituloInformacaoComplementar,
	DataInclusao,
	IdUsuarioInclusao,
	DataAtualizacao,
	IdUsuarioAtualizacao,
	IdTitulo,
	TipoContrato,
	AgenciaPlataforma,
	RegiaoPlataforma,
	NumeroRecebimento,
	DataContratacao,
	DataVencimentoContratoFatura,
	ValorContratoAtualizado,
	QuantidadeParcelaAtraso,
	ValorContratoVencimento,
	Empresa,
	DataEnvioContrato,
	DataLimiteRetornoContrato,
	CodigoParecerEscritorioAnterior,
	ParecerEscritorioAnterior1,
	ParecerEscritorioAnterior2,
	CodigoFilial,
	ValorEncargosContrato,
	CodigoEstrategia,
	TarifaCobranca,
	FaseCobranca,
	CodigoSegurador,
	CodigoOperacaoFinaustria,
	NumeroContratoFinaustria,
	CreditoImobiliarioSUSLIM,
	EstrategiaIDSTG1,
	DataAtivacaoCobrancaConsorcio,
	NumeroCartao,
	AgenciaContaCedenteDAC,
	CodigoCarteira,
	ValorAcordoPL,
	CodigoOcorrenciaCobrancaJuridico,
	CategoriaVeiculoCliente,
	NumeroParcela,
	IdTituloOriginal,
	ContratoPiloto,
	DataExclusao,
	IdUsuarioExclusao,
	ValidoDe,
	ValidoAte,
	ValorEntradaDiferenciada,
	DataEntregaAmigavel,
	DataUltimoAtraso,
	DataVencimentoProximaParcela,
	CodigoFamiliaProduto,
	QuantidadeParcelasAbertoContrato,
	QuantidadeParcelasPagas,
	DataUltimoEnvioEmail,
	DataUltimoEnvioPush,
	DataUltimoEnvioSMS,
	ValorMinimoFatura,
	ValorSaldoTotalFatura,
	QuantidadeDiasUtilizaLis,
	ValorSaldoTotalFaturaSistema,
	QuantParcelamentosFatura,
	ValorReferenciaFatura,
	ValorMinimoFaturaSistema,
	DataUltimoPagamentoFatura,
	CodigoEscritorioCobranca,
	NomeProduto,
	AreaNegocio,
	QuantidadeDiasAtraso,
	CodigoSubnivelCarteira,
	CodigoClusterScore,
	CodigoMotivoExclusao,
	Origem,
	CorrelationID,
	ValorTotalRiscoVencido,
	QuantidadeTotalParcelas,
	ValorContratoNoVencimento,
	TaxaJurosNominal,
	CodigoRenavam,
	IndicadorSaldoRemanescente,
	DataVendaVeiculo,
	DataApreensaoVeiculo,
	IndicadorAcaoContra,
	CodigoPlacaVeiculo,
	AnoModeloVeiculo,
	AnoFabricacaoVeiculo,
	ModeloMarcaVeiculo,
	DataVencimentoContrato,
	DataUltimaParcelaConsig,
	ValorUltimoPagamentoConsignado,
	ValorSaldoDevedorContabil
From #TitulosInformacoesComplementares a With(nolock)
Where
	Not exists (Select 1
				From misitau.dbo.TitulosInformacoesComplementares b With(nolock)
				Where
					a.IdTituloInformacaoComplementar = b.IdTituloInformacaoComplementar);

Set @LinhasInseridas = @@RowCount;

------------------------------> Atualizacao de dados

Set @Etapa = 'Atualizacao de dados';

--- | Atualiza campos da tabela fisica

Update a
Set	a.DataInclusao = b.DataInclusao,
    a.IdUsuarioInclusao = b.IdUsuarioInclusao,
    a.DataAtualizacao = b.DataAtualizacao,
    a.IdUsuarioAtualizacao = b.IdUsuarioAtualizacao,
    a.IdTitulo = b.IdTitulo,
    a.TipoContrato = b.TipoContrato,
    a.AgenciaPlataforma = b.AgenciaPlataforma,
    a.RegiaoPlataforma = b.RegiaoPlataforma,
    a.NumeroRecebimento = b.NumeroRecebimento,
    a.DataContratacao = b.DataContratacao,
    a.DataVencimentoContratoFatura = b.DataVencimentoContratoFatura,
    a.ValorContratoAtualizado = b.ValorContratoAtualizado,
    a.QuantidadeParcelaAtraso = b.QuantidadeParcelaAtraso,
    a.ValorContratoVencimento = b.ValorContratoVencimento,
    a.Empresa = b.Empresa,
    a.DataEnvioContrato = b.DataEnvioContrato,
    a.DataLimiteRetornoContrato = b.DataLimiteRetornoContrato,
    a.CodigoParecerEscritorioAnterior = b.CodigoParecerEscritorioAnterior,
    a.ParecerEscritorioAnterior1 = b.ParecerEscritorioAnterior1,
    a.ParecerEscritorioAnterior2 = b.ParecerEscritorioAnterior2,
    a.CodigoFilial = b.CodigoFilial,
    a.ValorEncargosContrato = b.ValorEncargosContrato,
    a.CodigoEstrategia = b.CodigoEstrategia,
    a.TarifaCobranca = b.TarifaCobranca,
    a.FaseCobranca = b.FaseCobranca,
    a.CodigoSegurador = b.CodigoSegurador,
    a.CodigoOperacaoFinaustria = b.CodigoOperacaoFinaustria,
    a.NumeroContratoFinaustria = b.NumeroContratoFinaustria,
    a.CreditoImobiliarioSUSLIM = b.CreditoImobiliarioSUSLIM,
    a.EstrategiaIDSTG1 = b.EstrategiaIDSTG1,
    a.DataAtivacaoCobrancaConsorcio = b.DataAtivacaoCobrancaConsorcio,
    a.NumeroCartao = b.NumeroCartao,
    a.AgenciaContaCedenteDAC = b.AgenciaContaCedenteDAC,
    a.CodigoCarteira = b.CodigoCarteira,
    a.ValorAcordoPL = b.ValorAcordoPL,
    a.CodigoOcorrenciaCobrancaJuridico = b.CodigoOcorrenciaCobrancaJuridico,
    a.CategoriaVeiculoCliente = b.CategoriaVeiculoCliente,
    a.NumeroParcela = b.NumeroParcela,
    a.IdTituloOriginal = b.IdTituloOriginal,
    a.ContratoPiloto = b.ContratoPiloto,
    a.DataExclusao = b.DataExclusao,
    a.IdUsuarioExclusao = b.IdUsuarioExclusao,
    a.ValidoDe = b.ValidoDe,
    a.ValidoAte = b.ValidoAte,
    a.ValorEntradaDiferenciada = b.ValorEntradaDiferenciada,
    a.DataEntregaAmigavel = b.DataEntregaAmigavel,
    a.DataUltimoAtraso = b.DataUltimoAtraso,
    a.DataVencimentoProximaParcela = b.DataVencimentoProximaParcela,
    a.CodigoFamiliaProduto = b.CodigoFamiliaProduto,
    a.QuantidadeParcelasAbertoContrato = b.QuantidadeParcelasAbertoContrato,
    a.QuantidadeParcelasPagas = b.QuantidadeParcelasPagas,
    a.DataUltimoEnvioEmail = b.DataUltimoEnvioEmail,
    a.DataUltimoEnvioPush = b.DataUltimoEnvioPush,
    a.DataUltimoEnvioSMS = b.DataUltimoEnvioSMS,
    a.ValorMinimoFatura = b.ValorMinimoFatura,
    a.ValorSaldoTotalFatura = b.ValorSaldoTotalFatura,
    a.QuantidadeDiasUtilizaLis = b.QuantidadeDiasUtilizaLis,
    a.ValorSaldoTotalFaturaSistema = b.ValorSaldoTotalFaturaSistema,
    a.QuantParcelamentosFatura = b.QuantParcelamentosFatura,
    a.ValorReferenciaFatura = b.ValorReferenciaFatura,
    a.ValorMinimoFaturaSistema = b.ValorMinimoFaturaSistema,
    a.DataUltimoPagamentoFatura = b.DataUltimoPagamentoFatura,
    a.CodigoEscritorioCobranca = b.CodigoEscritorioCobranca,
    a.NomeProduto = b.NomeProduto,
    a.AreaNegocio = b.AreaNegocio,
    a.QuantidadeDiasAtraso = b.QuantidadeDiasAtraso,
    a.CodigoSubnivelCarteira = b.CodigoSubnivelCarteira,
    a.CodigoClusterScore = b.CodigoClusterScore,
    a.CodigoMotivoExclusao = b.CodigoMotivoExclusao,
    a.Origem = b.Origem,
    a.CorrelationID = b.CorrelationID,
    a.ValorTotalRiscoVencido = b.ValorTotalRiscoVencido,
    a.QuantidadeTotalParcelas = b.QuantidadeTotalParcelas,
    a.ValorContratoNoVencimento = b.ValorContratoNoVencimento,
    a.TaxaJurosNominal = b.TaxaJurosNominal,
    a.CodigoRenavam = b.CodigoRenavam,
    a.IndicadorSaldoRemanescente = b.IndicadorSaldoRemanescente,
    a.DataVendaVeiculo = b.DataVendaVeiculo,
    a.DataApreensaoVeiculo = b.DataApreensaoVeiculo,
    a.IndicadorAcaoContra = b.IndicadorAcaoContra,
    a.CodigoPlacaVeiculo = b.CodigoPlacaVeiculo,
    a.AnoModeloVeiculo = b.AnoModeloVeiculo,
    a.AnoFabricacaoVeiculo = b.AnoFabricacaoVeiculo,
    a.ModeloMarcaVeiculo = b.ModeloMarcaVeiculo,
    a.DataVencimentoContrato = b.DataVencimentoContrato,
    a.DataUltimaParcelaConsig = b.DataUltimaParcelaConsig,
    a.ValorUltimoPagamentoConsignado = b.ValorUltimoPagamentoConsignado,
    a.ValorSaldoDevedorContabil = b.ValorSaldoDevedorContabil
From misitau.dbo.TitulosInformacoesComplementares a With(nolock)
Inner join #TitulosInformacoesComplementares b With(nolock) on a.IdTituloInformacaoComplementar = b.IdTituloInformacaoComplementar
Where
	Isnull(a.DataAtualizacao,'1900-01-01') <> Isnull(b.DataAtualizacao,'1900-01-01');

Set @LinhasAtualizadas = @@RowCount;
Set @LinhasTotaisDestino = @LinhasInseridas + @LinhasAtualizadas;
Set @DataHoraFim = Dateadd(hour,-3,Getdate());

/* Grava volumetria controles de log */
Exec misitau.[log].ProcControles
	@TipoLog = 'Volumetria',
	@IdExecucao = @IdExecucao,
	@NomeTabelaOrigem = 'cli.TitulosInformacoesComplementares',
	@NomeTabelaDestino = 'dbo.TitulosInformacoesComplementares',
	@LinhasOrigem = @LinhasOrigem,
	@LinhasInseridas = @LinhasInseridas,
	@LinhasAtualizadas = @LinhasAtualizadas,
	@LinhasTotaisDestino = @LinhasTotaisDestino;

/* Finaliza execução controles de log concluido */
Exec misitau.[log].ProcControles
	@TipoLog = 'Atualizacao',
	@IdExecucao = @IdExecucao,
	@DataHoraFim = @DataHoraFim,
	@StatusExecucao = 'Concluida';

End try
Begin Catch

Set @MensagemErro = Error_message();
Set @NumeroErro = Error_number();
Set @LinhaErro = Error_line()

/* Finalizacao execução de log erro */
Set @DataHoraFim = Dateadd(hour,-3,Getdate());
Exec misitau.[log].ProcControles
	@TipoLog = 'Atualizacao',
	@IdExecucao = @IdExecucao,
	@DataHoraFim = @DataHoraFim,
	@StatusExecucao = 'Erro';

/* Execução log erro */
Exec misitau.[log].ProcControles
		@TipoLog = 'Erro',
		@IdExecucao = @IdExecucao,
		@NomeProcedure = @NomeProcedure,
		@MensagemErro = @MensagemErro,
		@NumeroErro = @NumeroErro,
		@LinhaErro = @LinhaErro,
		@EtapaErro = @Etapa;

End Catch;