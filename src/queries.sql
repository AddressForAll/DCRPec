
-- Imported tables:
CREATE SCHEMA IF NOT EXISTS imported;

   -- Create extension dblink
   CREATE EXTENSION IF NOT EXISTS dblink;

   -- Import jurisdiction to build file name
   DROP TABLE IF EXISTS imported.jurisdiction CASCADE;
   CREATE TABLE IF NOT EXISTS imported.jurisdiction AS
   SELECT * FROM dblink(
       'dbname=dl05s_main',
       'SELECT isolabel_ext, osm_id, jurisd_local_id as cod_ibge, name, isolevel FROM optim.jurisdiction WHERE jurisd_base_id = 76'
   ) AS t (
       isolabel_ext character varying,
       osm_id bigint,
       cod_ibge integer,
       "name" character varying,
       isolevel integer
   );


-- Determina a tipologia
DROP MATERIALIZED VIEW IF EXISTS public.cep_tipologia CASCADE;
CREATE MATERIALIZED VIEW public.cep_tipologia AS
SELECT cep5, cep, tipo_cep
FROM (
    SELECT
        substring(cep,1,5)::int as cep5, cep,
        'LOCALIDADE'::text AS tipo_cep
    FROM public.log_localidade
    WHERE nullif(btrim(cep), '') IS NOT NULL

    UNION ALL

    SELECT
        substring(l.cep,1,5)::int, l.cep,
        'LOGRADOURO' || CASE
            WHEN
                   l.log_complemento ~* '\mlado\M'
                OR l.log_complemento ~* '\maté\M'
                OR l.log_complemento ~* '\mde[[:space:]]+[0-9]'
                OR l.log_complemento ~* '\mao fim\M'
                THEN '-SECCIONADO_EXPLICITO'
            WHEN s.log_nu IS NOT NULL
                THEN '-ABRANGENCIA_NUMERICA'
            ELSE '-SIMPLES'
        END
    FROM public.log_logradouro l
    LEFT JOIN log_num_sec s USING (log_nu)
    WHERE nullif(btrim(l.cep), '') IS NOT NULL

    UNION ALL

    SELECT substring(cep,1,5)::int, cep, 'GRANDE_USUARIO'
    FROM public.log_grande_usuario
    WHERE nullif(btrim(cep), '') IS NOT NULL

    UNION ALL

    SELECT substring(cep,1,5)::int, cep, 'UNIDADE_OPERACIONAL'
    FROM public.log_unid_oper
    WHERE nullif(btrim(cep), '') IS NOT NULL

    UNION ALL

    SELECT substring(cep,1,5)::int, cep, 'CAIXA_POSTAL'
    FROM public.log_cpc
    WHERE nullif(btrim(cep), '') IS NOT NULL
) q;

DROP INDEX IF EXISTS public.cep_tipologia_idx1cep; CREATE UNIQUE INDEX cep_tipologia_idx1cep ON public.cep_tipologia(cep);
DROP INDEX IF EXISTS public.cep_tipologia_idx1cep; CREATE INDEX cep_tipologia_idx1cep ON public.cep_tipologia(cep5);

-- Statistics
   -- %
   CREATE or replace VIEW cep_tipologia_tot AS
     WITH tot AS (SELECT count(*) t FROM cep_tipologia)
     SELECT tipo_cep, count(*) n,  
                    round(100.0*count(*)/tot.t,1)::text||'%' as percent
     FROM  public.cep_tipologia , tot
     GROUP BY tipo_cep, tot.t ORDER BY 1 
   ; --- select * from cep_tipologia_tot;
   -- Counting
   /*
   SELECT tipo_cep, COUNT(*) n_ceps FROM public.cep_tipologia GROUP BY 1 ORDER BY 1;
   */


-----------------------
-- FUNCTIONS : BEGIN --
-----------------------


   -- Detectar como os tipos de logradouros são abreviados por engenharia reversa
   /*
   WITH base_processada AS (
       SELECT 
           trim(tlo_tx) AS tipo_original,
           log_no,
           log_no_abrev,
           -- Pega a string toda menos o tamanho do nome da rua no final
           trim(substring(log_no_abrev FROM 1 FOR length(log_no_abrev) - length(log_no))) AS sigla_crua
       FROM public.log_logradouro
       WHERE tlo_tx IS NOT NULL 
         AND log_no_abrev IS NOT NULL
         AND log_no IS NOT NULL
         AND right(log_no_abrev, length(log_no)) = log_no
   ),
   base_limpa AS (
       SELECT 
           tipo_original,
           -- 1. unaccent: remove acentos e cedilha (ex: ç -> c)
           -- 2. regexp_replace: remove espaços, ordinais (ª, º), hífens e qualquer caractere não alfanumérico
           trim(regexp_replace(unaccent(sigla_crua), '[^a-zA-Z0-9]', '', 'g')) AS sigla_extraida
       FROM base_processada
       WHERE sigla_crua <> '' 
         AND sigla_crua <> tipo_original
   )
   SELECT 
       tipo_original,
       sigla_extraida,
       COUNT(*) AS freq
   FROM base_limpa
   WHERE sigla_extraida <> ''
   GROUP BY tipo_original, sigla_extraida
   ORDER BY tipo_original, freq DESC;
   */


-- Cria e popula tabelas tipo e título :: Vide arquivo insert_tipo_titulo_logradouros.sql --


CREATE EXTENSION IF NOT EXISTS unaccent;

-- 1. Função para encolher/abreviar o Tipo de Logradouro conforme os Correios (sem ponto)
DROP FUNCTION IF EXISTS endereco_to_camel_correios CASCADE;
DROP FUNCTION IF EXISTS shrink_logradouro_tipo;
CREATE OR REPLACE FUNCTION shrink_logradouro_tipo(p_tipo text) RETURNS text
LANGUAGE sql STABLE STRICT PARALLEL SAFE -- STABLE (ou IMMUTABLE se a tabela for tratada como estática)
AS $$
  SELECT abreviacao 
  FROM logradouro_tipo_map 
  WHERE tipo_normalizado = lower(unaccent(trim(p_tipo)));
$$;

-- 2. Função para encolher/abreviar Títulos conforme os Correios (sem ponto)
DROP FUNCTION IF EXISTS endereco_to_camel_correios CASCADE;
DROP FUNCTION IF EXISTS shrink_logradouro_titulo;
CREATE OR REPLACE FUNCTION shrink_logradouro_titulo(p_titulo text) RETURNS text
LANGUAGE sql STABLE STRICT PARALLEL SAFE
AS $$
  SELECT abreviacao 
  FROM public.logradouro_titulo_map 
  WHERE titulo_normalizado = lower(unaccent(trim(p_titulo)));
$$;

-- 3. Função principal que processa a string inteira de forma colada (CamelCase)
DROP FUNCTION IF EXISTS endereco_to_camel_correios CASCADE;
CREATE OR REPLACE FUNCTION endereco_to_camel_correios(
    p_name text, 
    p_processar_tipo_titulo boolean DEFAULT true
) RETURNS text
LANGUAGE plpgsql IMMUTABLE STRICT PARALLEL SAFE
AS $$
DECLARE
    v_clean text;
    v_palavras text[];
    v_total_palv int;
    v_tipo text := '';
    v_titulo text := NULL;
    v_resto text := '';
    i int := 1;
    k int;
    v_slice text;
    v_res text;
    v_p_lower text;
    v_is_ultima boolean;
    v_resultado text := '';
    v_forbidden_words text[] := ARRAY['de', 'da', 'do', 'dos', 'das', 'no', 'na', 'nos', 'nas', 'pela', 'pelo', 'para', 'em', 'por', 'com', 'e', 'a', 'o', 'as', 'os'];
BEGIN
    v_clean := p_name;
    
    -- 1. Limpeza inicial estruturada (sem regex complexa para o Av.)
    -- Remove parênteses e conteúdo (inclusive abertos sem fechar)
    v_clean := regexp_replace(v_clean, '\([^)]*(\)|$)', '', 'g');
    
    -- Remove S/N ou S/Nº (case-insensitive)
    v_clean := regexp_replace(v_clean, '(?i)\bS/Nº?\b', '', 'g');
    
    -- Remove completamente apóstrofos, aspas, ª, º, °, ?, ¿, vírgulas e hífens
    v_clean := translate(v_clean, '''"ªº°?¿,-', '');
    
    -- Normaliza espaços múltiplos
    v_clean := trim(regexp_replace(v_clean, '\s+', ' ', 'g'));

    -- Quebra em array de palavras
    v_palavras := regexp_split_to_array(v_clean, '\s+');
    v_total_palv := array_length(v_palavras, 1);

    IF v_total_palv IS NULL OR v_total_palv = 0 OR (v_total_palv = 1 and v_palavras[1] = '') THEN
        RETURN '';
    END IF;

    -- TRATAMENTO DIRETO DO ARRAY: Se a primeira palavra for "Av." ou "Av", troca por "Avenida"
    IF lower(v_palavras[1]) = 'av.' OR lower(v_palavras[1]) = 'av' THEN
        v_palavras[1] := 'Avenida';
    END IF;

    i := 1;

    -- Se o parâmetro estiver ativo, executa a detecção de tipo e título
    IF p_processar_tipo_titulo THEN
        -- 2. Detecção do TIPO
        FOR k IN REVERSE LEAST(v_total_palv, 3)..1 LOOP
            v_slice := array_to_string(v_palavras[1:k], ' ');
            v_res := shrink_logradouro_tipo(v_slice);
            IF v_res IS NOT NULL AND v_res <> '' THEN
                v_tipo := v_res;
                i := k + 1;
                EXIT;
            END IF;
        END LOOP;

        -- Fallback se nenhum tipo cadastrado for encontrado
        IF v_tipo = '' AND v_total_palv >= 1 THEN
            v_tipo := initcap(unaccent(v_palavras[1]));
            i := 2;
        END IF;

        -- 3. Detecção do TÍTULO
        IF i <= v_total_palv THEN
            FOR k IN REVERSE LEAST(v_total_palv - i + 1, 3)..1 LOOP
                v_slice := array_to_string(v_palavras[i:i+k-1], ' ');
                v_res := shrink_logradouro_titulo(v_slice);
                IF v_res IS NOT NULL AND v_res <> '' 
                   AND NOT (lower(unaccent(v_res)) = ANY(v_forbidden_words)) THEN
                    v_titulo := v_res;
                    i := i + k;
                    EXIT;
                END IF;
            END LOOP;
        END IF;
    ELSE
        i := 1;
    END IF;

    -- 4. Processamento do RESTO
    WHILE i <= v_total_palv LOOP
        IF v_palavras[i] IS NOT NULL AND v_palavras[i] <> '' THEN
            v_p_lower := lower(unaccent(v_palavras[i]));
            v_is_ultima := (i = v_total_palv);

            IF NOT v_is_ultima AND v_p_lower = ANY(v_forbidden_words) THEN
                i := i + 1;
                CONTINUE;
            END IF;

            v_resto := v_resto || initcap(unaccent(regexp_replace(v_palavras[i], '[\.]', '', 'g')));
        END IF;
        i := i + 1;
    END LOOP;

    -- 5. Montagem Final segura
    IF v_tipo <> '' THEN
        v_resultado := v_tipo;
    END IF;
    
    IF v_titulo IS NOT NULL AND v_titulo <> '' THEN
        v_resultado := CASE WHEN v_resultado = '' THEN v_titulo ELSE v_resultado || '_' || v_titulo END;
    END IF;
    
    IF v_resto <> '' THEN
        v_resultado := CASE WHEN v_resultado = '' THEN v_resto ELSE v_resultado || '_' || v_resto END;
    END IF;

    -- Substitui barra por ponto
    v_resultado := replace(v_resultado, '/', '.');

    RETURN v_resultado;
END;
$$;

-----------------------
-- FUNCTIONS : END   --
-----------------------


-- Gera materialized view public.cep_string_padronizada 
DROP MATERIALIZED VIEW IF EXISTS public.cep_string_padronizada;
CREATE MATERIALIZED VIEW public.cep_string_padronizada AS
SELECT 
    -- Endereço Postal Legível
    TRIM(
        CASE 
            WHEN t.tipo_cep IN ('LOCALIDADE') THEN 
                COALESCE(NULLIF(BTRIM(c.bairro), ''), c.municipio)
            ELSE 
                COALESCE(c.logradouro, '') || 
                CASE 
                    WHEN t.tipo_cep IN ('GRANDE_USUARIO', 'UNIDADE_OPERACIONAL', 'CAIXA_POSTAL') 
                         AND NULLIF(BTRIM(c.complemento), '') IS NOT NULL 
                    THEN ', ' || c.complemento 
                    ELSE ''
                END ||
                CASE WHEN NULLIF(BTRIM(c.bairro), '') IS NOT NULL THEN ' • ' || c.bairro ELSE '' END
        END ||
        CASE WHEN NULLIF(BTRIM(c.municipio), '') IS NOT NULL THEN ', ' || c.municipio ELSE '' END ||
        CASE WHEN NULLIF(BTRIM(c.uf), '') IS NOT NULL THEN ' - ' || c.uf ELSE '' END ||
        ', CEP ' || LEFT(t.cep, 5) || '-' || RIGHT(t.cep, 3)
    ) AS endereco_postal,
     
    -- String Compacta Hierárquica estrita
    CASE 
        -- Caso C1: Grandes Usuários / Caixas Postais / Unidades
        WHEN t.tipo_cep IN ('GRANDE_USUARIO', 'UNIDADE_OPERACIONAL', 'CAIXA_POSTAL') 
        THEN SUBSTRING(j.isolabel_ext, 4) || '-' || 
             endereco_to_camel_correios(COALESCE(c.logradouro, '')) || 
             CASE WHEN NULLIF(BTRIM(c.complemento), '') IS NOT NULL THEN '~' || SUBSTRING(c.complemento FROM '^\s*([0-9]+[ABC]?)') ELSE '' END
        
        -- Caso C2: Logradouros Comuns
        WHEN t.tipo_cep IN ('LOGRADOURO-ABRANGENCIA_NUMERICA', 'LOGRADOURO-SECCIONADO_EXPLICITO', 'LOGRADOURO-SIMPLES') 
        THEN SUBSTRING(j.isolabel_ext, 4) || '-' || 
             endereco_to_camel_correios(COALESCE(c.logradouro, ''))
        
        -- Caso C3: Localidade 
        WHEN t.tipo_cep IN ('LOCALIDADE') 
        THEN 
            CASE 
                WHEN NULLIF(BTRIM(c.bairro), '') IS NULL 
                     OR TRIM(c.bairro) = TRIM(c.municipio)
                THEN SUBSTRING(j.isolabel_ext, 4)
                ELSE SUBSTRING(j.isolabel_ext, 4) || '-' || endereco_to_camel_correios(c.bairro, FALSE)
            END
    END AS string_compacta,
    
    -- Classificação do Caso
    CASE 
        WHEN t.tipo_cep IN ('GRANDE_USUARIO', 'UNIDADE_OPERACIONAL', 'CAIXA_POSTAL') THEN 'C1'
        WHEN t.tipo_cep IN ('LOGRADOURO-ABRANGENCIA_NUMERICA', 'LOGRADOURO-SECCIONADO_EXPLICITO', 'LOGRADOURO-SIMPLES') THEN 'C2'
        WHEN t.tipo_cep IN ('LOCALIDADE') THEN 'C3'
    END AS caso,

    -- Coluna para o "Tipo-Falta"
    CASE 
        WHEN t.tipo_cep IN ('LOGRADOURO-ABRANGENCIA_NUMERICA', 'LOGRADOURO-SECCIONADO_EXPLICITO', 'LOGRADOURO-SIMPLES') 
        THEN 'C2-numero_predial'
        WHEN t.tipo_cep IN ('LOCALIDADE') 
        THEN 'C3-bairro_e_numero'
        ELSE 'C1-'
    END AS tipo_falta,

    t.cep AS cep_bruto

FROM public.cep_tipologia t
LEFT JOIN public.cep_unificado c 
       ON BTRIM(t.cep::text) = BTRIM(c.cep::text)
LEFT JOIN imported.jurisdiction j 
       ON c.municipio_cod_ibge::bigint = j.cod_ibge::bigint;

-- Índice essencial para performance na string compacta final
CREATE INDEX idx_cep_string_compacta ON public.cep_string_padronizada (string_compacta);





