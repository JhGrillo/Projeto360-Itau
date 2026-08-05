Create or Alter procedure log.ProcControleExpurgo as

------------------------------> Descrição da procedure

/*
    Padrão de escrita: PascalCase
    Nome: ProcControleExpurgo
    DataCriação: 05/08/2026
    Criado por: João Henrique Cavalheiro Grillo
    DataAtualização:
    Atualizado por:

    Descrição atualização: (Data, Atualizado por, Descrição, git)
*/

------------------------------> Definições de variaveis e controles de ambiente

Set Nocount On;

Declare @NomeProcedure varchar(128) = 'ProcControleExpurgo',
        @Etapa varchar(100) = 'Inicio',
        @IdDevedor int,
        @UltimaAtualizacao datetime,
        @IdExecucao int,
        @DataHoraInicio datetime = Getdate(),
        @DataHoraFim datetime,
        @MensagemErro varchar(max),
        @NumeroErro int,
        @LinhaErro int,
        @IdTabelaExpurgo int,
		@NomeTabela varchar(64),
		@HoraExpurgo time,
		@Contador int,
		@SQLExpurgo nvarchar(max);

/* Inicia o controle de logs */
Exec dbDataDwItau.log.ProcControles
    @TipoLog = 'Execucao',
    @NomeProcedure = @NomeProcedure,
    @DataHoraInicio = @DataHoraInicio,
    @StatusExecucao = 'Executando',
    @IdExecucao = @IdExecucao OUTPUT;

Begin Try

------------------------------> Criacao de tabelas temporarias

Set @Etapa = 'Criacao das tabelas temporarias';

--- | Tabela de Controle Expurgo

If Object_id('Tempdb..#TabelasControleExpurgo') Is not null Drop table #TabelasControleExpurgo;
Create table #TabelasControleExpurgo (
	IdTabelaExpurgo int,
	NomeTabela varchar(64),
	HoraExpurgo time,
	Executado int
);

------------------------------> Carga das tabelas temporarias

Set @Etapa = 'Carga das tabelas temporarias';

--- | Insere tabelas que serão Expurgadas 

Insert into #TabelasControleExpurgo (IdTabelaExpurgo, NomeTabela, HoraExpurgo, Executado)
Select
	a.IdTabelaExpurgo,
	a.NomeTabela,
	a.HoraExpurgo,
	b.Executado
From dbDataDwItau.log.TabelasControleExpurgo a
Left join (Select distinct
			    IdTabelaExpurgo,
			    1 as Executado
		   From dbDataDwItau.log.ControleExpurgo
		   Where 
                DataExecucao >= Convert(date,Getdate())) b on a.IdTabelaExpurgo = b.IdTabelaExpurgo;

------------------------------> Controle de expurgo

Set @Etapa = 'Controle de expurgo';

Set @Contador = (Select 
	                Count(IdTabelaExpurgo)
                From #TabelasControleExpurgo);

Set @IdTabelaExpurgo = 1;

While @IdTabelaExpurgo <= @Contador
Begin
	Set @NomeTabela = (Select 
                        NomeTabela 
                       From #TabelasControleExpurgo 
                       Where 
                        IdTabelaExpurgo = @IdTabelaExpurgo 
                        and HoraExpurgo <= Convert(time,Getdate())
                        and Executado is null);

	If @NomeTabela is not null 
	Begin 
		Set @SQLExpurgo = N'
	
			Truncate table ' + @NomeTabela;

		Exec sp_executesql @SQLExpurgo;


		Exec dbDataDwItau.log.ProcControles
            @TipoLog = 'Expurgo',
		    @IdTabelaExpurgo = @IdTabelaExpurgo,
		    @NomeTabela = @NomeTabela;
	End;
	Set @IdTabelaExpurgo += 1;

End

Set @DataHoraFim = Getdate();

/* Finaliza execução controles de log concluido */
Exec dbDataDwItau.log.ProcControles
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
Set @DataHoraFim = Getdate();
Exec dbDataDwItau.log.ProcControles
    @TipoLog = 'Atualizacao',
    @IdExecucao = @IdExecucao,
    @DataHoraFim = @DataHoraFim,
    @StatusExecucao = 'Erro';

/* Execução log erro */
Exec dbDataDwItau.log.ProcControles
    @TipoLog = 'Erro',
    @IdExecucao = @IdExecucao,
    @NomeProcedure = @NomeProcedure,
    @MensagemErro = @MensagemErro,
    @NumeroErro = @NumeroErro,
    @LinhaErro = @LinhaErro,
    @EtapaErro = @Etapa;

End Catch;