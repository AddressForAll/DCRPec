
------------------------------------------------------------------------
-- 1. Criação das Tabelas Tipo e Titulo com suas abreviações
------------------------------------------------------------------------

DROP TABLE IF EXISTS public.logradouro_tipo_map;
CREATE TABLE public.logradouro_tipo_map (
    tipo_normalizado TEXT PRIMARY KEY,
    abreviacao TEXT NOT NULL
);

DROP TABLE IF EXISTS public.logradouro_titulo_map;
CREATE TABLE public.logradouro_titulo_map (
    titulo_normalizado TEXT PRIMARY KEY,
    abreviacao TEXT NOT NULL
);

-- =====================================================================
-- 2. Importação dos Dados via \COPY usando terminal
-- =====================================================================
/*

-- Estando na pasta data, executar: psql -U user_name -d db_name

\copy public.logradouro_tipo_map(tipo_normalizado, abreviacao) FROM 'logradouro_tipo_map.csv' WITH (FORMAT csv, HEADER true, DELIMITER ',');

\copy public.logradouro_titulo_map(titulo_normalizado, abreviacao) FROM 'logradouro_titulo_map.csv' WITH (FORMAT csv, HEADER true, DELIMITER ',');

*/
