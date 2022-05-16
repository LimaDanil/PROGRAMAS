create or replace package LKM_REL_DCI_ZFM_CPROC is

-- Declaracao de Variavels Globais

  mLinha    VARCHAR2(1000);
  mLinha2   VARCHAR2(1000);
  mLinha3   VARCHAR2(1000);

  -- Declaracao de Variaveis de Trabalho
  wEmpresa  empresa%rowtype;
  wEtab     estabelecimento%rowtype;
  v_erroSql varchar2(500);
  v_MsgErro varchar2(500) := '@';
  sep       varchar2(2) := '| ';
  sep2      varchar2(2) := '  ';
  vtext     varchar2(100) := ' ';
  vHeader   varchar2(100);

  FUNCTION Parametros RETURN VARCHAR2;
  FUNCTION Nome RETURN VARCHAR2;
  FUNCTION Tipo RETURN VARCHAR2;
  FUNCTION Versao RETURN VARCHAR2;
  FUNCTION Descricao RETURN VARCHAR2;
  FUNCTION Modulo RETURN VARCHAR2;
  FUNCTION Classificacao RETURN VARCHAR2;
  FUNCTION Executar(

                    p_codestab varchar2,
                    p_DataIni  Date,
                    p_DataFim  Date
    )
  RETURN INTEGER;


end;
/
CREATE OR REPLACE PACKAGE BODY LKM_REL_DCI_ZFM_CPROC
IS
  -- variaveis de status
  MCOD_ESTAB   ESTABELECIMENTO.COD_ESTAB%TYPE;
  MCOD_EMPRESA EMPRESA.COD_EMPRESA%TYPE;
  MUSUARIO     USUARIO_ESTAB.COD_USUARIO%TYPE;


  FUNCTION PARAMETROS RETURN VARCHAR2 IS
    PSTR VARCHAR2(5000);
    DATA_INI DATE;
    DATA_FIM DATE;

  BEGIN

    MCOD_EMPRESA := LIB_PARAMETROS.RECUPERAR('EMPRESA');
    MCOD_ESTAB   := NVL(LIB_PARAMETROS.RECUPERAR('ESTABELECIMENTO'), '');
    MUSUARIO     := LIB_PARAMETROS.RECUPERAR('USUARIO');

    -- Razao Social
    Begin
      select Razao_social, cnpj
        into wEmpresa.razao_social, wEmpresa.Cnpj
        from empresa
       where cod_empresa = mcod_empresa;
    exception
      when others then
        wEmpresa.razao_social := 'Nao Identificada';
    end;

    begin
      select trunc(last_day(add_months(sysdate, -2))) + 1 ini,
             trunc(last_day(add_months(sysdate, -1))) fim
        into DATA_INI, DATA_FIM
        from dual;
    end;

    LIB_PROC.ADD_PARAM(PSTR, lpad(' ', 62, ' '), 'varchar2', 'Text', 'N');
    LIB_PROC.ADD_PARAM(PSTR,
                       lpad(' ', 62, ' ') ||
                       '*****  RELATÓRIO DCI_ZFM  *****',
                       'varchar2',
                       'Text',
                       'N');
    LIB_PROC.ADD_PARAM(PSTR, lpad(' ', 62, ' '), 'varchar2', 'Text', 'N');

    LIB_PROC.ADD_PARAM(PSTR,
                       lpad(' ', 45, ' ') || 'Empresa:   ' ||
                       wEmpresa.razao_social,
                       'varchar2',
                       'Text',
                       'N');

    LIB_PROC.ADD_PARAM(PSTR,
                       'Estabelecimento',
                       'Varchar2',
                       'ComboBox',
                       'N',
                       NULL,
                       NULL,
                       'select '' TODOS'', ''Todos os estabelecimentos'' from dual
                       union all
                       select distinct estab.cod_estab, estab.cod_estab || '' - '' || estab.razao_social razao_social
                         FROM estabelecimento estab
                         where 1 = 1
                           and estab.cod_empresa = ''' || MCOD_EMPRESA || '''
                           and estab.cod_estab = nvl(''' || MCOD_ESTAB || ''',estab.cod_estab)
                        order by 1');

    LIB_PROC.ADD_PARAM(PSTR,
                       'Data inicial',
                       'Date',
                       'Textbox',
                       'N',
                       DATA_INI,
                       'DD/MM/YYYY',
                       'S');

    LIB_PROC.ADD_PARAM(PSTR,
                       'Data final',
                       'Date',
                       'Textbox',
                       'N',
                       DATA_FIM,
                       'DD/MM/YYYY',
                       'S');

    LIB_PROC.ADD_PARAM(PSTR, lpad(' ', 62, ' '), 'varchar2', 'Text', 'N');

    LIB_PROC.ADD_PARAM(PSTR,
                       'Modulo Desenvolvido para ' || wEmpresa.razao_social,
                       'varchar2',
                       'Text',
                       'N');

    LIB_PROC.ADD_PARAM(PSTR,
                       'Versao : ' || VERSAO,
                       'varchar2',
                       'Text',
                       'N');

    RETURN PSTR;
  END;

  FUNCTION NOME RETURN VARCHAR2 IS
  BEGIN
    RETURN 'RELATÓRIO DCI_ZFM';
  END;

  FUNCTION TIPO RETURN VARCHAR2 IS
  BEGIN
    RETURN 'RELATÓRIOS';
  END;

  FUNCTION VERSAO RETURN VARCHAR2 IS
  BEGIN
    RETURN '1.0';
  END;

  FUNCTION DESCRICAO RETURN VARCHAR2 IS
  BEGIN
    RETURN 'Geração de Relatório da DCI_ZFM';
  END;

  FUNCTION MODULO RETURN VARCHAR2 IS
  BEGIN
    RETURN 'Processos Customizados';
  END;

  FUNCTION CLASSIFICACAO RETURN VARCHAR2 IS
  BEGIN
    RETURN 'Processos Customizados';
  END;

  function executar(
                    p_codestab varchar2,
                    p_DataIni  Date,
                    p_DataFim  Date)
    return integer is

  /* Vari·veis de Trabalho */
  mproc_id   INTEGER;
  mLinha     VARCHAR2(10000);
  vRegistroH NUMBER := 0;

  CURSOR C_PISCOFINS
  IS
    SELECT X07.COD_EMPRESA,
       X07.COD_ESTAB,
       X07.DATA_FISCAL,
       b5.clas_item,
       b5.COD_PRODUTO,
       b5.DESCRICAO AS DESCRICAO_PRODUTO,
       b5.vlr_reservado1,
       b6.COD_MEDIDA,
       X07.Num_Docfis_Ref,
       x08.num_item,
       X08.QUANTIDADE,
       UF.COD_ESTADO,
       TRIM(REPLACE(X08.VLR_CONTAB_ITEM, '.', ',')) VLR_CONTAB_ITEM,
       b2.COD_CFO,
       b7.COD_NBM,
       x49.num_nf,
       b8.cod_fis_jur,
       x49.num_di

  FROM X08_ITENS_MERC     X08,
       X07_DOCTO_FISCAL   X07,
       X49_OPER_IMP       X49,
       X2012_COD_FISCAL   b2,
       X2013_PRODUTO      b5,
       X2007_MEDIDA       b6,
       X2043_COD_NBM      b7,

       X04_PESSOA_FIS_JUR b8,
       ESTADO             UF

 WHERE 1 = 1
   AND X07.COD_EMPRESA = X08.COD_EMPRESA
   AND X07.COD_ESTAB = X08.COD_ESTAB
   AND X07.DATA_FISCAL = X08.DATA_FISCAL
   AND X07.MOVTO_E_S = X08.MOVTO_E_S
   AND X07.NORM_DEV = X08.NORM_DEV
   AND X07.IDENT_DOCTO = X08.IDENT_DOCTO
   AND X07.IDENT_FIS_JUR = X08.IDENT_FIS_JUR
   AND X07.NUM_DOCFIS = X08.NUM_DOCFIS
   AND X07.SERIE_DOCFIS = X08.SERIE_DOCFIS
   AND X07.SUB_SERIE_DOCFIS = X08.SUB_SERIE_DOCFIS
   AND X07.NUM_DOCFIS_REF = X49.NUM_NF
   AND x07.serie_docfis_ref = x49.serie_nf
   AND x07.s_ser_docfis_ref = x49.sub_serie_nf
   AND X08.IDENT_CFO = b2.IDENT_CFO
   AND x49.IDENT_PRODUTO = b5.IDENT_PRODUTO
   AND X49.IDENT_MEDIDA = b6.IDENT_MEDIDA
   AND X49.IDENT_NBM = b7.IDENT_NBM
   AND x07.COD_EMPRESA = X49.COD_EMPRESA
   AND x07.COD_ESTAB = X49.COD_ESTAB
   AND x08.IDENT_PRODUTO = X49.IDENT_PRODUTO
   AND x49.Ident_Fis_Jur = b8.IDENT_FIS_JUR
   AND X07.IDENT_UF_DESTINO = UF.IDENT_ESTADO
   AND x07.cod_empresa = MCOD_EMPRESA
   AND x07.cod_estab = decode(p_codestab,' TODOS',x07.cod_estab,p_codestab)
   AND x07.data_fiscal BETWEEN to_date(p_dataini, 'dd/mm/yyyy') AND to_date(p_datafim, 'dd/mm/yyyy')
   AND b2.cod_cfo in (select det.Conteudo
                        from fpar_param_det det, fpar_parametros par, fpar_param_estab estab
                       where par.nome_framework = 'LKM_REL_CREDITO_ICMS_CPAR'
                         and det.id_parametro = par.id_parametros
                         and det.nome_param     = 'CFOPCI'
                         and det.id_parametro   = estab.id_parametros)

    ORDER BY 2 ASC,
      3 ASC,
      4 ASC;


 BEGIN
      -- Cria Processo --
    mproc_id := lib_proc.new('LKM_REL_DCI_ZFM_CPROC');
    -- C ria Arquivos --
    lib_proc.add_tipo(mproc_id, 1, 'Relatorio_Pis_Cofins - Heineken.csv', 2);
    mLinha := 'EMPRESA;ESTABELECIMENTO;PERIODO;TIPO_DE_MATERIAL;CODIGO_MATERIAL;DESCRICAO_PRODUTO;DCRE;UNIDADE;NF_SAIDA;ITEM;QUANTIDADE;UF;VALOR_TOTAL;CFOP;NCM;NF_IMP;FORNECEDOR;DI;';
    lib_proc.add(mLinha, NULL, NULL, 1);



    FOR c_reg IN C_PISCOFINS
    LOOP
      mLinha := '';
      mLinha := mLinha || c_reg.COD_EMPRESA || ';';
      mLinha := mLinha || c_reg.COD_ESTAB || ';';
      mLinha := mLinha || c_reg.DATA_FISCAL || ';';
      mLinha := mLinha || c_reg.clas_item || ';';
      mLinha := mLinha || c_reg.COD_PRODUTO || ';';
      mLinha := mLinha || c_reg.DESCRICAO_PRODUTO || ';';
      mLinha := mLinha || c_reg.vlr_reservado1 || ';';
      mLinha := mLinha || c_reg.COD_MEDIDA || ';';
      mLinha := mLinha || c_reg.num_docfis_ref || ';';
      mLinha := mLinha || c_reg.num_item || ';';
      mLinha := mLinha || c_reg.QUANTIDADE || ';';
      mLinha := mLinha || c_reg.cod_estado || ';';
      mLinha := mLinha || c_reg.VLR_CONTAB_ITEM || ';';
      mLinha := mLinha || c_reg.COD_CFO || ';';
      mLinha := mLinha || c_reg.COD_NBM || ';';
      mLinha := mLinha || c_reg.num_nf || ';';
      mLinha := mLinha || c_reg.cod_fis_jur || ';';
      mLinha := mLinha || c_reg.num_di || ';';

      lib_proc.add(mLinha, NULL, NULL, 1);
      vRegistroH := vRegistroH + 1;
    END LOOP;
    lib_proc.add_log(vRegistroH || ' Registro(s)  gerado(s) para o relatorio DCI_ZFM.', 1);

    --lib_proc.add_log(ps_cfop, 1);

    lib_proc.close();



    RETURN mproc_id;
  END;
END;
/
