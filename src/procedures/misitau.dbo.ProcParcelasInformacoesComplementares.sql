Create or Alter procedure dbo.ProcParcelasInformacoesComplementares as

------------------------------> Descrição da procedure

/*
    Padrão de escrita: PascalCase
    Nome: ProcParcelasInformacoesComplementares
    DataCriação: 22/07/2026
    Criado por: João Henrique Cavalheiro Grillo
    DataAtualização:
    Atualizado por:

    Descrição atualização: (Data, Atualizado por, Descrição, git)
*/

------------------------------> Definições de variaveis e controles de ambiente

Set nocount on;

Declare @NomeProcedure varchar(128) = 'ProcParcelasInformacoesComplementares',
    @Etapa varchar(100) = 'Inicio',
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
    @LinhaErro int,
    @Tabela varchar(25);

/* Inicia o controle de logs */
Exec misitau.[log].ProcControles
    @TipoLog = 'Execucao',
    @NomeProcedure = @NomeProcedure,
    @DataHoraInicio = @DataHoraInicio,
    @StatusExecucao = 'Executando',
    @IdExecucao = @IdExecucao OUTPUT;

Begin try

------------------------------> Carga das tabelas temporarias

Set @Etapa = 'Carga das tabelas temporarias';

--- | Parcelas informações complementares

If Object_id('Tempdb..#ParcelasInformacoesComplementares') Is not null Drop table #ParcelasInformacoesComplementares;
Create table #ParcelasInformacoesComplementares (
	IdParcelaInformacaoComplementar int,
	DataInclusao datetime,
	IdUsuarioInclusao int,
	DataAtualizacao datetime,
	IdUsuarioAtualizacao int,
	IdParcela int,
	DataReabertura date,
	ValidoDe datetime2,
	ValidoAte datetime2
);

------------------------------> Carga das tabelas temporarias

Set @Etapa = 'Carga das tabelas temporarias';

Set @UltimaAtualizacao = (Select 
							Case
								when Datepart(hour,Max(DataHoraInicio)) >= 22 then Max(Dateadd(day,+1,Convert(date,DataHoraInicio)))
								else Max(Convert(date,DataHoraInicio))
							end
						 From misitau.[log].ControleExecucoes
						 Where
							NomeProcedure = 'ProcParcelasInformacoesComplementares'
							and StatusExecucao = 'Concluida');

--- | Dados origem

If Object_id('Tempdb..#DadosOrigem') Is not null Drop table #DadosOrigem;
Select
	IdParcelaInformacaoComplementar,
	DataInclusao,
	IdUsuarioInclusao,
	DataAtualizacao,
	IdUsuarioAtualizacao,
	IdParcela,
	DataReabertura,
	ValidoDe,
	ValidoAte
into #DadosOrigem
From misitau.cli.ParcelasInformacoesComplementares a
Where
	DataReabertura is not null
	and Exists (Select 1
				From cob.Parcelas b
				Where
					a.IdParcela = b.IdParcela
					and (b.IdSituacaoParcela = 'A'
					or b.DataAtualizacao >= @UltimaAtualizacao));

/* Cria index clusterizado 
Obs: Este index é criado fora da etapa de index devido a necessidade de performance no comparativo abaixo.
*/
Create nonclustered Index IxParcelasInformacoesComplementares on #DadosOrigem (IdParcelaInformacaoComplementar);

--- | Insere apenas oque não existe na tabela ou que foi atualizado

Insert into #ParcelasInformacoesComplementares (
												IdParcelaInformacaoComplementar,
												DataInclusao,
												IdUsuarioInclusao,
												DataAtualizacao,
												IdUsuarioAtualizacao,
												IdParcela,
												DataReabertura,
												ValidoDe,
												ValidoAte
												)
Select
	IdParcelaInformacaoComplementar,
	DataInclusao,
	IdUsuarioInclusao,
	DataAtualizacao,
	IdUsuarioAtualizacao,
	IdParcela,
	DataReabertura,
	ValidoDe,
	ValidoAte
From #DadosOrigem a
Where
	Not exists (Select 1
				From misitau.dbo.ParcelasInformacoesComplementares b With(nolock)
				Where
					a.IdParcelaInformacaoComplementar = b.IdParcelaInformacaoComplementar
					and ((a.DataAtualizacao = b.DataAtualizacao)
					or (a.DataAtualizacao is null and b.DataAtualizacao is null)));

Set @LinhasOrigem = @@RowCount;

------------------------------> Criacao de índices

Set @Etapa = 'Criacao de indices';

/* Cria index não clusterizado */
Create nonclustered Index IxParcelasInformacoesComplementares on #ParcelasInformacoesComplementares (IdParcelaInformacaoComplementar);

------------------------------> Persistencia final

Set @Etapa = 'Persistencia final';

--- | Tabela fisica

Insert into misitau.dbo.ParcelasInformacoesComplementares(
														IdParcelaInformacaoComplementar,
														DataInclusao,
														IdUsuarioInclusao,
														DataAtualizacao,
														IdUsuarioAtualizacao,
														IdParcela,
														DataReabertura,
														ValidoDe,
														ValidoAte
														)
Select distinct
    IdParcelaInformacaoComplementar,
	DataInclusao,
	IdUsuarioInclusao,
	DataAtualizacao,
	IdUsuarioAtualizacao,
	IdParcela,
	DataReabertura,
	ValidoDe,
	ValidoAte
From #ParcelasInformacoesComplementares a With(nolock)
Where
 Not exists (Select 1
             From misitau.dbo.ParcelasInformacoesComplementares b With(nolock)
             Where
                a.IdParcelaInformacaoComplementar = b.IdParcelaInformacaoComplementar);

Set @LinhasInseridas = @@RowCount;

------------------------------> Atualizacao de dados

Set @Etapa = 'Atualizacao de dados';

--- | Atualiza campos da tabela fisica

Update a
Set a.DataAtualizacao = b.DataAtualizacao,
    a.IdUsuarioAtualizacao = b.IdUsuarioAtualizacao,
    a.DataReabertura = b.DataReabertura,
	a.ValidoDe = b.ValidoDe,
	a.ValidoAte = b.ValidoAte
From misitau.dbo.ParcelasInformacoesComplementares a With(nolock)
Inner join #ParcelasInformacoesComplementares b With(nolock) on a.IdParcelaInformacaoComplementar = b.IdParcelaInformacaoComplementar
Where
	Isnull(a.DataAtualizacao,'1900-01-01') <> Isnull(b.DataAtualizacao,'1900-01-01');

Set @LinhasAtualizadas = @@RowCount;
Set @LinhasTotaisDestino = @LinhasInseridas + @LinhasAtualizadas;
Set @DataHoraFim = Dateadd(hour,-3,Getdate());

/* Grava volumetria controles de log */
Exec misitau.[log].ProcControles
    @TipoLog = 'Volumetria',
    @IdExecucao = @IdExecucao,
    @NomeTabelaOrigem = 'cli.ParcelasInformacoesComplementares',
    @NomeTabelaDestino = 'dbo.ParcelasInformacoesComplementares',
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

End Try
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