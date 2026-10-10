
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


-- Cria e popula tabelas tipo e título --

   -- Cria e popula a tabela tipo com as tuplas nome_completo : nome_abreviado
   DROP TABLE IF EXISTS public.logradouro_tipo_map;
   CREATE TABLE IF NOT EXISTS public.logradouro_tipo_map (
       tipo_normalizado TEXT PRIMARY KEY,
       abreviacao TEXT NOT NULL
   );
      -- Insert all your mappings into the table
      INSERT INTO public.logradouro_tipo_map (tipo_normalizado, abreviacao) VALUES
          ('10ª avenida', '10Av'),
          ('10ª travessa', '10Tv'),
          ('11ª avenida', '11Av'),
          ('11ª travessa', '11Tv'),
          ('12ª rua', '12R'),
          ('12ª travessa', '12Tv'),
          ('13ª travessa', '13Tv'),
          ('14ª travessa', '14Tv'),
          ('15ª travessa', '15Tv'),
          ('16ª travessa', '16Tv'),
          ('17ª travessa', '17Tv'),
          ('18ª travessa', '18Tv'),
          ('19ª travessa', '19Tv'),
          ('1ª avenida', '1Av'),
          ('1ª escadaria', '1Escad'),
          ('1ª ladeira', '1Ld'),
          ('1ª paralela', '1Par'),
          ('1ª rua', '1R'),
          ('1ª subida', '1Sub'),
          ('1ª travessa', '1Tv'),
          ('1ª travessa da avenida', '1TvdaAv'),
          ('1ª travessa da rodovia', '1TvdaRod'),
          ('1ª travessa da rua', '1TvdaR'),
          ('1ª via coletora', '1VColet'),
          ('1ª viela', '1Vla'),
          ('1ª vila', '1Vl'),
          ('1º acesso', '1Ac'),
          ('1º alto', '1At'),
          ('1º beco', '1Bc'),
          ('20ª travessa', '20Tv'),
          ('21ª travessa', '21Tv'),
          ('22ª travessa', '22Tv'),
          ('26ª travessa', '26Tv'),
          ('2ª avenida', '2Av'),
          ('2ª escadaria', '2Escad'),
          ('2ª ladeira', '2Ld'),
          ('2ª paralela', '2Par'),
          ('2ª rua', '2R'),
          ('2ª subida', '2Sub'),
          ('2ª travessa', '2Tv'),
          ('2ª travessa da rodovia', '2TvRod'),
          ('2ª travessa da rua', '2TvdaR'),
          ('2ª via coletora', '2VColet'),
          ('2ª viela', '2Vla'),
          ('2ª vila', '2Vl'),
          ('2º acesso', '2Ac'),
          ('2º alto', '2At'),
          ('2º beco', '2Bc'),
          ('3ª avenida', '3Av'),
          ('3ª escadaria', '3Escad'),
          ('3ª ladeira', '3Ld'),
          ('3ª paralela', '3Par'),
          ('3ª rua', '3R'),
          ('3ª subida', '3Sub'),
          ('3ª travessa', '3Tv'),
          ('3ª travessa da rua', '3TvdaR'),
          ('3ª vila', '3Vl'),
          ('3º acesso', '3Ac'),
          ('3º alto', '3At'),
          ('3º beco', '3Bc'),
          ('4ª avenida', '4Av'),
          ('4ª escadaria', '4Escad'),
          ('4ª paralela', '4Par'),
          ('4ª rua', '4R'),
          ('4ª subida', '4Sub'),
          ('4ª travessa', '4Tv'),
          ('4ª travessa da rua', '4TvdaR'),
          ('4ª vila', '4Vl'),
          ('4º alto', '4At'),
          ('4º beco', '4Bc'),
          ('5ª avenida', '5Av'),
          ('5ª escadaria', '5Escad'),
          ('5ª rua', '5R'),
          ('5ª subida', '5Sub'),
          ('5ª travessa', '5Tv'),
          ('5ª travessa da rua', '5TvdaR'),
          ('5ª vila', '5Vl'),
          ('5º alto', '5At'),
          ('5º beco', '5Bc'),
          ('6ª avenida', '6Av'),
          ('6ª escadaria', '6Escad'),
          ('6ª subida', '6Sub'),
          ('6ª travessa', '6Tv'),
          ('6ª vila', '6Vl'),
          ('6º beco', '6Bc'),
          ('7ª avenida', '7Av'),
          ('7ª escadaria', '7Escad'),
          ('7ª travessa', '7Tv'),
          ('8ª avenida', '8Av'),
          ('8ª escadaria', '8Escad'),
          ('8ª travessa', '8Tv'),
          ('9ª avenida', '9Av'),
          ('9ª rua', '9R'),
          ('9ª travessa', '9Tv'),
          -- Sem acentuação / variações com 'a' e 'o'
          ('10a avenida', '10Av'),
          ('10a travessa', '10Tv'),
          ('11a avenida', '11Av'),
          ('11a travessa', '11Tv'),
          ('12a rua', '12R'),
          ('12a travessa', '12Tv'),
          ('13a travessa', '13Tv'),
          ('14a travessa', '14Tv'),
          ('15a travessa', '15Tv'),
          ('16a travessa', '16Tv'),
          ('17a travessa', '17Tv'),
          ('18a travessa', '18Tv'),
          ('19a travessa', '19Tv'),
          ('1a avenida', '1Av'),
          ('1a escadaria', '1Escad'),
          ('1a ladeira', '1Ld'),
          ('1a paralela', '1Par'),
          ('1a rua', '1R'),
          ('1a subida', '1Sub'),
          ('1a travessa', '1Tv'),
          ('1a travessa da avenida', '1TvdaAv'),
          ('1a travessa da rodovia', '1TvdaRod'),
          ('1a travessa da rua', '1TvdaR'),
          ('1a via coletora', '1VColet'),
          ('1a viela', '1Vla'),
          ('1a vila', '1Vl'),
          ('1o acesso', '1Ac'),
          ('1o alto', '1At'),
          ('1o beco', '1Bc'),
          ('20a travessa', '20Tv'),
          ('21a travessa', '21Tv'),
          ('22a travessa', '22Tv'),
          ('26a travessa', '26Tv'),
          ('2a avenida', '2Av'),
          ('2a escadaria', '2Escad'),
          ('2a ladeira', '2Ld'),
          ('2a paralela', '2Par'),
          ('2a rua', '2R'),
          ('2a subida', '2Sub'),
          ('2a travessa', '2Tv'),
          ('2a travessa da rodovia', '2TvRod'),
          ('2a travessa da rua', '2TvdaR'),
          ('2a via coletora', '2VColet'),
          ('2a viela', '2Vla'),
          ('2a vila', '2Vl'),
          ('2o acesso', '2Ac'),
          ('2o alto', '2At'),
          ('2o beco', '2Bc'),
          ('3a avenida', '3Av'),
          ('3a escadaria', '3Escad'),
          ('3a ladeira', '3Ld'),
          ('3a paralela', '3Par'),
          ('3a rua', '3R'),
          ('3a subida', '3Sub'),
          ('3a travessa', '3Tv'),
          ('3a travessa da rua', '3TvdaR'),
          ('3a vila', '3Vl'),
          ('3o acesso', '3Ac'),
          ('3o alto', '3At'),
          ('3o beco', '3Bc'),
          ('4a avenida', '4Av'),
          ('4a escadaria', '4Escad'),
          ('4a paralela', '4Par'),
          ('4a rua', '4R'),
          ('4a subida', '4Sub'),
          ('4a travessa', '4Tv'),
          ('4a travessa da rua', '4TvdaR'),
          ('4a vila', '4Vl'),
          ('4o alto', '4At'),
          ('4o beco', '4Bc'),
          ('5a avenida', '5Av'),
          ('5a escadaria', '5Escad'),
          ('5a rua', '5R'),
          ('5a subida', '5Sub'),
          ('5a travessa', '5Tv'),
          ('5a travessa da rua', '5TvdaR'),
          ('5a vila', '5Vl'),
          ('5o alto', '5At'),
          ('5o beco', '5Bc'),
          ('6a avenida', '6Av'),
          ('6a escadaria', '6Escad'),
          ('6a subida', '6Sub'),
          ('6a travessa', '6Tv'),
          ('6a vila', '6Vl'),
          ('6o beco', '6Bc'),
          ('7a avenida', '7Av'),
          ('7a escadaria', '7Escad'),
          ('7a travessa', '7Tv'),
          ('8a avenida', '8Av'),
          ('8a escadaria', '8Escad'),
          ('8a travessa', '8Tv'),
          ('9a avenida', '9Av'),
          ('9a rua', '9R'),
          ('9a travessa', '9Tv'),
          -- Demais tipos
          ('acampamento', 'Acamp'),
          ('acesso', 'Ac'),
          ('acesso estadual', 'AcEstd'),
          ('acesso local', 'AcLoc'),
          ('acesso para rua', 'AcR'),
          ('aeroporto', 'Aer'),
          ('alameda', 'Al'),
          ('alca de acesso', 'AlcAces'),
          ('aldeia', 'Ald'),
          ('aldeia indigena', 'AldInd'),
          ('alto', 'At'),
          ('anel', 'An'),
          ('anel viario', 'AnVr'),
          ('antiga estacao', 'AntEtc'),
          ('antiga estrada', 'AntEst'),
          ('area', 'A'),
          ('area especial', 'AE'),
          ('area verde', 'AVerde'),
          ('arteria', 'Art'),
          ('atalho', 'Atl'),
          ('avenida', 'Av'),
          ('avenida circular', 'AvCirc'),
          ('avenida contorno', 'AvCont'),
          ('avenida industrial', 'AvInd'),
          ('avenida marginal', 'AvMarg'),
          ('avenida marginal direita', 'AvMargDir'),
          ('avenida marginal esquerda', 'AvMargEsq'),
          ('avenida perimetral', 'AvPer'),
          ('baixa', 'Bx'),
          ('beco', 'Bc'),
          ('beco 1', 'Bc1'),
          ('beco 2', 'Bc2'),
          ('bloco', 'Bl'),
          ('blocos', 'Bls'),
          ('bosque', 'Bsq'),
          ('boulevard', 'Bvd'),
          ('bulevar', 'Blv'),
          ('buraco', 'Bco'),
          ('cais', 'C'),
          ('calcada', 'Calc'),
          ('calcadao', 'Calc'),
          ('caminho', 'Cam'),
          ('caminho de servidao', 'CamServ'),
          ('campo', 'Cpo'),
          ('canal', 'Can'),
          ('centro', 'Centr'),
          ('chacara', 'Ch'),
          ('ciclovia', 'Cicl'),
          ('circular', 'Circ'),
          ('colina', 'Clna'),
          ('colonia', 'Col'),
          ('complexo viario', 'CmpVr'),
          ('comunidade', 'Com'),
          ('comunidade quilombola', 'ComQuilomb'),
          ('comunidade rural', 'ComRura'),
          ('comunidade urbana', 'ComUrba'),
          ('condominio', 'Cond'),
          ('condominio residencial', 'CondRes'),
          ('conjunto', 'Cj'),
          ('conjunto habitacional', 'CjHab'),
          ('conjunto residencial', 'CjRes'),
          ('contorno', 'Cont'),
          ('corredor', 'Cor'),
          ('corrego', 'Crg'),
          ('descida', 'Dsc'),
          ('desvio', 'Dsv'),
          ('distrito', 'Dt'),
          ('edificio', 'Ed'),
          ('eixo', 'Ex'),
          ('eixo industrial', 'ExInd'),
          ('eixo principal', 'ExPrinc'),
          ('entrada particular', 'EntPart'),
          ('escada', 'Esc'),
          ('escada de pedra', 'EscPedra'),
          ('escadao', 'Esco'),
          ('escadaria', 'Escad'),
          ('esplanada', 'Esp'),
          ('estacao', 'Etc'),
          ('estacao transformadora', 'EctTrans'),
          ('estacionamento', 'Estc'),
          ('estadio', 'Etd'),
          ('estrada', 'Est'),
          ('estrada antiga', 'EstAnt'),
          ('estrada de ferro', 'EstFer'),
          ('estrada de ligacao', 'EstLig'),
          ('estrada de servidao', 'EstSrv'),
          ('estrada ecoturistica', 'EstEcot'),
          ('estrada estadual', 'EstEstd'),
          ('estrada federal', 'EstFed'),
          ('estrada intermunicipal', 'EstInterm'),
          ('estrada marginal', 'EstMarg'),
          ('estrada municipal', 'EstMun'),
          ('estrada nova', 'EstN'),
          ('estrada para', 'Estpra'),
          ('estrada particular', 'EstPart'),
          ('estrada real', 'EstReal'),
          ('estrada velha', 'EstVelha'),
          ('estrada vicinal', 'EstVic'),
          ('estrada vicinal municipal', 'EstVicMun'),
          ('faixa', 'Fx'),
          ('favela', 'Fav'),
          ('fazenda', 'Faz'),
          ('feira', 'Fra'),
          ('ferrovia', 'Fer'),
          ('fonte', 'Fnt'),
          ('forte', 'Fte'),
          ('galeria', 'Gal'),
          ('gleba', 'Glb'),
          ('granja', 'Gja'),
          ('ilha', 'Ia'),
          ('jardim', 'Jd'),
          ('jardim publico', 'JdPub'),
          ('jardim residencial', 'JdRes'),
          ('jardinete', 'Jde'),
          ('ladeira', 'Ld'),
          ('lago', 'Lg'),
          ('lagoa', 'Lga'),
          ('largo', 'Lrg'),
          ('ligacao', 'Lig'),
          ('localidade', 'Loc'),
          ('loteamento', 'Lot'),
          ('margem', 'Mrg'),
          ('marginal', 'Marg'),
          ('marina', 'Mna'),
          ('mercado', 'Merc'),
          ('modulo', 'Mod'),
          ('monte', 'Mte'),
          ('morro', 'Mro'),
          ('nova avenida', 'NAv'),
          ('nucleo habitacional', 'NucHab'),
          ('nucleo rural', 'NucRural'),
          ('ocupacao', 'Ocup'),
          ('orla fluvial', 'OrFl'),
          ('parada', 'Pda'),
          ('paralela', 'Par'),
          ('parque', 'Prq'),
          ('parque municipal', 'PrqMunic'),
          ('parque residencial', 'PrqRes'),
          ('passagem', 'Psg'),
          ('passagem de pedestres', 'PsgPed'),
          ('passagem particular', 'PsgPart'),
          ('passagem subterranea', 'PsgSub'),
          ('passarela', 'Psa'),
          ('passeio', 'Pas'),
          ('passeio publico', 'PasPub'),
          ('patio', 'Pat'),
          ('pedestre', 'Ped'),
          ('ponta', 'Pta'),
          ('ponte', 'Pte'),
          ('porto', 'Pto'),
          ('povoado', 'Pov'),
          ('praca', 'Pc'),
          ('praca de esportes', 'PcEsp'),
          ('praia', 'Pr'),
          ('prolongamento', 'Prl'),
          ('prolongamento da avenida', 'PrlAv'),
          ('prolongamento da rua', 'PrlR'),
          ('quadra', 'Q'),
          ('ramal', 'Ram'),
          ('rampa', 'Rmp'),
          ('recanto', 'Rec'),
          ('residencial', 'Res'),
          ('reta', 'Ret'),
          ('retorno', 'Rtn'),
          ('rodo anel', 'RodAn'),
          ('rodovia', 'Rod'),
          ('rodovia de acesso', 'RodAc'),
          ('rodovia estadual', 'RodEstd'),
          ('rodovia municipal', 'RodMun'),
          ('rodovia vicinal', 'RodVic'),
          ('rotatoria', 'Rtt'),
          ('rotula', 'Rot'),
          ('rua', 'R'),
          ('rua circular', 'RCirc'),
          ('rua contorno', 'RCont'),
          ('rua de ligacao', 'RLig'),
          ('rua de pedestre', 'RPed'),
          ('rua ferroviaria', 'RFerr'),
          ('rua integracao', 'RInteg'),
          ('rua particular', 'RPart'),
          ('rua principal', 'RPrinc'),
          ('rua projetada', 'RProj'),
          ('rua velha', 'RVelha'),
          ('rua vicinal', 'RVic'),
          ('ruela', 'Rla'),
          ('segunda avenida', 'SegAv'),
          ('semi anel viario', 'SAnV'),
          ('servidao', 'Srv'),
          ('servidao de passagem', 'SrvPsg'),
          ('setor', 'St'),
          ('sitio', 'Sit'),
          ('subida', 'Sub'),
          ('temporario', 'Temp'),
          ('terceira avenida', 'TercAv'),
          ('terminal', 'Ter'),
          ('tifa', 'Tf'),
          ('transversal', 'Transv'),
          ('travessa', 'Tv'),
          ('travessa da rua', 'TvdaRua'),
          ('travessa particular', 'TvPart'),
          ('travessa projetada', 'TvProj'),
          ('travessa velha', 'TvVelha'),
          ('travessia', 'Travess'),
          ('trecho', 'Tr'),
          ('trevo', 'Trv'),
          ('trilha', 'Tl'),
          ('tunel', 'Tun'),
          ('unidade', 'Unid'),
          ('vala', 'Val'),
          ('vale', 'Vle'),
          ('variante', 'Vrte'),
          ('variante da estrada', 'VrteEst'),
          ('vereda', 'Ver'),
          ('via', 'V'),
          ('via coletora', 'VColet'),
          ('via de acesso', 'VAc'),
          ('via de circulacao', 'VCirc'),
          ('via de pedestre', 'VPed'),
          ('via de pedestres', 'VPeds'),
          ('via diretriz', 'VlDir'),
          ('viaduto', 'Vd'),
          ('via estrada municipal', 'VEstMun'),
          ('via expressa', 'VExp'),
          ('via lateral', 'VLat'),
          ('via litoranea', 'VLit'),
          ('via local', 'VLocal'),
          ('via marginal', 'VMarg'),
          ('via municipal', 'VMun'),
          ('via pedestre', 'Vped'),
          ('via principal', 'VPrinc'),
          ('vicinal', 'Vc'),
          ('viela', 'Vla'),
          ('viela da rua', 'VladaR'),
          ('viela de acesso', 'VladeAc'),
          ('vila', 'Vl'),
          ('zigue-zague', 'ZigZag');

   
   -- Cria e popula a tabela titulos com as tuplas nome_completo : nome_abreviado para títulos
   DROP TABLE IF EXISTS public.logradouro_titulo_map;
   CREATE TABLE IF NOT EXISTS public.logradouro_titulo_map (
       titulo_normalizado TEXT PRIMARY KEY,
       abreviacao TEXT NOT NULL
   );
      -- Insert all your mappings into the table
      INSERT INTO public.logradouro_titulo_map (titulo_normalizado, abreviacao) VALUES
          ('doutor', 'Dr'),
          ('doutora', 'Dra'),
          ('coronel', 'Cel'),
          ('general', 'Gen'),
          ('major', 'Maj'),
          ('capitao', 'Cap'),
          ('tenente', 'Ten'),
          ('subtenente', 'Sgt'),
          ('sargento', 'Sgt'),
          ('professor', 'Prof'),
          ('professora', 'Profa'),
          ('padre', 'Pe'),
          ('frei', 'Frei'),
          ('pastor', 'Pr'),
          ('engenheiro', 'Eng'),
          ('engenheira', 'Enga'),
          ('vice prefeito', 'VicePref'),
          -- Lista de títulos do CNEFE
          ('abade', 'Abade'),
          ('abadessa', 'Abadessa'),
          ('abolicionista', 'Abolicionista'),
          ('academica', 'Academica'),
          ('academico', 'Academico'),
          ('administrador', 'Administrador'),
          ('administradora', 'Administradora'),
          ('admonitor', 'Admonitor'),
          ('advogada', 'Advogada'),
          ('advogado', 'Advogado'),
          ('advogado doutor', 'AdvogadoDoutor'),
          ('aeronauta', 'Aeronauta'),
          ('agente', 'Agente'),
          ('agente fiscal', 'AgenteFiscal'),
          ('agente postal', 'AgentePostal'),
          ('agricultor', 'Agricultor'),
          ('agricultora', 'Agricultora'),
          ('agrimensor', 'Agrimensor'),
          ('agronomo', 'Agronomo'),
          ('agropecuarista', 'Agropecuarista'),
          ('ajudante', 'Ajudante'),
          ('alcaide', 'Alcaide'),
          ('alcaidessa', 'Alcaidessa'),
          ('alfaiate', 'Alfaiate'),
          ('alfaqui', 'Alfaqui'),
          ('alferes', 'Alferes'),
          ('almirante', 'Almirante'),
          ('almocreve', 'Almocreve'),
          ('aluna', 'Aluna'),
          ('aluno', 'Aluno'),
          ('ancia', 'Ancia'),
          ('anciao', 'Anciao'),
          ('anjo', 'Anjo'),
          ('antiste', 'Antiste'),
          ('antropologo', 'Antropologo'),
          ('aposentada', 'Aposentada'),
          ('aposentado', 'Aposentado'),
          ('apostolo', 'Apostolo'),
          ('apresentador', 'Apresentador'),
          ('arabi', 'Arabi'),
          ('arcanjo', 'Arcanjo'),
          ('arcebispo', 'Arcebispo'),
          ('arcebispo dom', 'ArcebispoDom'),
          ('arcipreste', 'Arcipreste'),
          ('arquiteta', 'Arquiteta'),
          ('arquiteto', 'Arquiteto'),
          ('artesao', 'Artesao'),
          ('artifice', 'Artifice'),
          ('artista', 'Artista'),
          ('artista plastico', 'ArtistaPlastico'),
          ('aspirante', 'Aspirante'),
          ('assessor', 'Assessor'),
          ('assessora', 'Assessora'),
          ('assistente social', 'AssistenteSocial'),
          ('astronomo', 'Astronomo'),
          ('atleta', 'Atleta'),
          ('ator', 'Ator'),
          ('atriz', 'Atriz'),
          ('aviador', 'Aviador'),
          ('aviadora', 'Aviadora'),
          ('avo', 'Avo'),
          ('bacharel', 'Bacharel'),
          ('balconista', 'Balconista'),
          ('bancaria', 'Bancaria'),
          ('bancario', 'Bancario'),
          ('bandeirante', 'Bandeirante'),
          ('bandeirantes', 'Bandeirantes'),
          ('barao', 'Barao'),
          ('baronesa', 'Baronesa'),
          ('beata', 'Beata'),
          ('beata madre', 'BeataMadre'),
          ('beato', 'Beato'),
          ('benemerito', 'Benemerito'),
          ('benfeitor', 'Benfeitor'),
          ('bispo', 'Bispo'),
          ('bispo dom', 'BispoDom'),
          ('bombeiro', 'Bombeiro'),
          ('bonzo', 'Bonzo'),
          ('boto', 'Boto'),
          ('brigadeiro', 'Brigadeiro'),
          ('cabo', 'Cabo'),
          ('cabocla', 'Cabocla'),
          ('caboclo', 'Caboclo'),
          ('cabo policia militar', 'CaboPoliciaMilitar'),
          ('cacador', 'Cacador'),
          ('cacique', 'Cacique'),
          ('cadete', 'Cadete'),
          ('camarista', 'Camarista'),
          ('caminhoneiro', 'Caminhoneiro'),
          ('canonisa', 'Canonisa'),
          ('cantor', 'Cantor'),
          ('cantora', 'Cantora'),
          ('capataz', 'Capataz'),
          ('capelao', 'Capelao'),
          ('capitao aviador', 'CapitaoAviador'),
          ('capitao doutor', 'CapitaoDoutor'),
          ('capitao mor', 'CapitaoMor'),
          ('capitao policia militar', 'CapitaoPoliciaMilitar'),
          ('capitao tenente', 'CapitaoTenente'),
          ('carcereiro', 'Carcereiro'),
          ('cardeal', 'Cardeal'),
          ('cardeal dom', 'CardealDom'),
          ('carmelita', 'Carmelita'),
          ('carnavalesco', 'Carnavalesco'),
          ('carpinteiro', 'Carpinteiro'),
          ('carreteiro', 'Carreteiro'),
          ('carteiro', 'Carteiro'),
          ('cartunista', 'Cartunista'),
          ('catequista', 'Catequista'),
          ('cavalheiro', 'Cavalheiro'),
          ('centenario', 'Centenario'),
          ('ceramista', 'Ceramista'),
          ('chanceler', 'Chanceler'),
          ('chefe', 'Chefe'),
          ('cidadao', 'Cidadao'),
          ('cientista', 'Cientista'),
          ('cineasta', 'Cineasta'),
          ('cirurgiao', 'Cirurgiao'),
          ('coletor', 'Coletor'),
          ('colonizador', 'Colonizador'),
          ('colunista', 'Colunista'),
          ('comadre', 'Comadre'),
          ('comandante', 'Comandante'),
          ('combatente', 'Combatente'),
          ('comediante', 'Comediante'),
          ('comendadeira', 'Comendadeira'),
          ('comendador', 'Comendador'),
          ('comendador capitao', 'ComendadorCapitao'),
          ('comendador doutor', 'ComendadorDoutor'),
          ('comerciante', 'Comerciante'),
          ('comerciaria', 'Comerciaria'),
          ('comerciario', 'Comerciario'),
          ('comissaria', 'Comissaria'),
          ('comissario', 'Comissario'),
          ('comodoro', 'Comodoro'),
          ('compositor', 'Compositor'),
          ('comunitaria', 'Comunitaria'),
          ('comunitario', 'Comunitario'),
          ('conde', 'Conde'),
          ('condessa', 'Condessa'),
          ('conego', 'Conego'),
          ('confrade', 'Confrade'),
          ('conselheira', 'Conselheira'),
          ('conselheiro', 'Conselheiro'),
          ('conselheiro doutor', 'ConselheiroDoutor'),
          ('construtor', 'Construtor'),
          ('consul', 'Consul'),
          ('consulesa', 'Consulesa'),
          ('consultora', 'Consultora'),
          ('contabilista', 'Contabilista'),
          ('contador', 'Contador'),
          ('contadora', 'Contadora'),
          ('contra almirante', 'ContraAlmirante'),
          ('corneteiro', 'Corneteiro'),
          ('coronel aviador', 'CoronelAviador'),
          ('coronel pm', 'CoronelPm'),
          ('corredor', 'Corredor'),
          ('corretor', 'Corretor'),
          ('corretora', 'Corretora'),
          ('costureira', 'Costureira'),
          ('cronista', 'Cronista'),
          ('cunhada', 'Cunhada'),
          ('cunhado', 'Cunhado'),
          ('cura', 'Cura'),
          ('czar', 'Czar'),
          ('czarina', 'Czarina'),
          ('deao', 'Deao'),
          ('defensor publico', 'DefensorPublico'),
          ('delegada', 'Delegada'),
          ('delegado', 'Delegado'),
          ('dentista', 'Dentista'),
          ('deputada', 'Deputada'),
          ('deputado', 'Deputado'),
          ('deputado federal', 'DeputadoFederal'),
          ('desbravador', 'Desbravador'),
          ('desembargador', 'Desembargador'),
          ('desembargadora', 'Desembargadora'),
          ('desembargador doutor', 'DesembargadorDoutor'),
          ('desenhista', 'Desenhista'),
          ('despachante', 'Despachante'),
          ('desportista', 'Desportista'),
          ('detetive', 'Detetive'),
          ('diaconisa', 'Diaconisa'),
          ('diacono', 'Diacono'),
          ('dicionarista', 'Dicionarista'),
          ('diplomata', 'Diplomata'),
          ('diretor', 'Diretor'),
          ('diretora', 'Diretora'),
          ('doge', 'Doge'),
          ('dogesa', 'Dogesa'),
          ('dom', 'Dom'),
          ('domestica', 'Domestica'),
          ('dominicano', 'Dominicano'),
          ('dona', 'Dona'),
          ('dona sinha', 'DonaSinha'),
          ('doutor professor', 'DoutorProfessor'),
          ('druida', 'Druida'),
          ('druidisa', 'Druidisa'),
          ('duque', 'Duque'),
          ('duquesa', 'Duquesa'),
          ('ecologista', 'Ecologista'),
          ('economista', 'Economista'),
          ('educador', 'Educador'),
          ('educadora', 'Educadora'),
          ('eletricista', 'Eletricista'),
          ('emancipador', 'Emancipador'),
          ('embaixador', 'Embaixador'),
          ('embaixatriz', 'Embaixatriz'),
          ('empresario', 'Empresario'),
          ('enfermeira', 'Enfermeira'),
          ('enfermeiro', 'Enfermeiro'),
          ('engenheiro agronomo', 'EngenheiroAgronomo'),
          ('engenheiro quimico', 'EngenheiroQuimico'),
          ('escoteiro', 'Escoteiro'),
          ('escrava', 'Escrava'),
          ('escravo', 'Escravo'),
          ('escrevente', 'Escrevente'),
          ('escritor', 'Escritor'),
          ('escritora', 'Escritora'),
          ('escriva', 'Escriva'),
          ('escrivao', 'Escrivao'),
          ('escultor', 'Escultor'),
          ('escultora', 'Escultora'),
          ('esportista', 'Esportista'),
          ('estivador', 'Estivador'),
          ('estudante', 'Estudante'),
          ('evangelica', 'Evangelica'),
          ('evangelico', 'Evangelico'),
          ('evangelista', 'Evangelista'),
          ('evangelizador', 'Evangelizador'),
          ('ex combatente', 'ExCombatente'),
          ('expedicionario', 'Expedicionario'),
          ('expedicionario cabo', 'ExpedicionarioCabo'),
          ('expedicionarios', 'Expedicionarios'),
          ('ex prefeito', 'ExPrefeito'),
          ('farmaceutica', 'Farmaceutica'),
          ('farmaceutico', 'Farmaceutico'),
          ('feirante', 'Feirante'),
          ('ferroviaria', 'Ferroviaria'),
          ('ferroviario', 'Ferroviario'),
          ('filantropo', 'Filantropo'),
          ('filha', 'Filha'),
          ('filhas', 'Filhas'),
          ('filho', 'Filho'),
          ('filhos', 'Filhos'),
          ('filosofo', 'Filosofo'),
          ('fiscal', 'Fiscal'),
          ('fisico', 'Fisico'),
          ('folclorista', 'Folclorista'),
          ('fotografa', 'Fotografa'),
          ('fotografo', 'Fotografo'),
          ('fotografo jornalistico', 'FotografoJornalistico'),
          ('frade', 'Frade'),
          ('freira', 'Freira'),
          ('freire', 'Freire'),
          ('frei sao', 'FreiSao'),
          ('funcionaria', 'Funcionaria'),
          ('funcionaria publica', 'FuncionariaPublica'),
          ('funcionario', 'Funcionario'),
          ('funcionario publico', 'FuncionarioPublico'),
          ('fundador', 'Fundador'),
          ('furriel', 'Furriel'),
          ('garcon', 'Garcon'),
          ('general de divisao', 'GeneralDivisao'),
          ('general de exercito', 'GeneralExercito'),
          ('generalissimo', 'Generalissimo'),
          ('geografo', 'Geografo'),
          ('governador', 'Governador'),
          ('governadora', 'Governadora'),
          ('grafico', 'Grafico'),
          ('grao', 'Grao'),
          ('grao mestre', 'GraoMestre'),
          ('grumete', 'Grumete'),
          ('guarda', 'Guarda'),
          ('guarda civil', 'GuardaCivil'),
          ('guarda marinha', 'GuardaMarinha'),
          ('guarda mor', 'GuardaMor'),
          ('guarda municipal', 'GuardaMunicipal'),
          ('guarda territorial', 'GuardaTerritorial'),
          ('guerreiro', 'Guerreiro'),
          ('guia', 'Guia'),
          ('heroina', 'Heroina'),
          ('historiador', 'Historiador'),
          ('historiadora', 'Historiadora'),
          ('imaculada', 'Imaculada'),
          ('imaculado', 'Imaculado'),
          ('imigrante', 'Imigrante'),
          ('imigrantes', 'Imigrantes'),
          ('imperador', 'Imperador'),
          ('imperador dom', 'ImperadorDom'),
          ('imperatriz', 'Imperatriz'),
          ('imperatriz dona', 'ImperatrizDona'),
          ('india', 'India'),
          ('indio', 'Indio'),
          ('industrial', 'Industrial'),
          ('industriario', 'Industriario'),
          ('infante', 'Infante'),
          ('infante dom', 'InfanteDom'),
          ('inspetor', 'Inspetor'),
          ('inspetora', 'Inspetora'),
          ('intendente', 'Intendente'),
          ('intendente doutor', 'IntendenteDoutor'),
          ('interventor', 'Interventor'),
          ('investigador', 'Investigador'),
          ('investigador de policia', 'InvestigadorPolicia'),
          ('irma', 'Irma'),
          ('irmao', 'Irmao'),
          ('irmaos', 'Irmaos'),
          ('irmas', 'Irmas'),
          ('jangadeiro', 'Jangadeiro'),
          ('jardineira', 'Jardineira'),
          ('jardineiro', 'Jardineiro'),
          ('jesuita', 'Jesuita'),
          ('jornalista', 'Jornalista'),
          ('jovem', 'Jovem'),
          ('juiz', 'Juiz'),
          ('juiza', 'Juiza'),
          ('juiz de direito', 'JuizDireito'),
          ('juiz de paz', 'JuizPaz'),
          ('junior', 'Junior'),
          ('jurista', 'Jurista'),
          ('laboratorista', 'Laboratorista'),
          ('lavrador', 'Lavrador'),
          ('legionario', 'Legionario'),
          ('leiloeiro', 'Leiloeiro'),
          ('libertador', 'Libertador'),
          ('lider comunitario', 'LiderComunitario'),
          ('livreiro', 'Livreiro'),
          ('locutor', 'Locutor'),
          ('locutora', 'Locutora'),
          ('lord', 'Lord'),
          ('lorde', 'Lorde'),
          ('madame', 'Madame'),
          ('madre', 'Madre'),
          ('madrinha', 'Madrinha'),
          ('madrinheiro', 'Madrinheiro'),
          ('mae', 'Mae'),
          ('maestrina', 'Maestrina'),
          ('maestro', 'Maestro'),
          ('maestro reverendo', 'MaestroReverendo'),
          ('magistrado', 'Magistrado'),
          ('major aviador', 'MajorAviador'),
          ('major brigadeiro', 'MajorBrigadeiro'),
          ('major brigadeiro do ar', 'MajorBrigadeiroAr'),
          ('major de exercito', 'MajorExercito'),
          ('major doutor', 'MajorDoutor'),
          ('major policia militar', 'MajorPoliciaMilitar'),
          ('maquinista', 'Maquinista'),
          ('maraja', 'Maraja'),
          ('marceneiro', 'Marceneiro'),
          ('marchante', 'Marchante'),
          ('marechal', 'Marechal'),
          ('marechal do ar', 'MarechalAr'),
          ('marinheiro', 'Marinheiro'),
          ('maritimo', 'Maritimo'),
          ('marques', 'Marques'),
          ('marquesa', 'Marquesa'),
          ('marujo', 'Marujo'),
          ('mecanico', 'Mecanico'),
          ('medica', 'Medica'),
          ('medico', 'Medico'),
          ('medico industrial', 'MedicoIndustrial'),
          ('medium', 'Medium'),
          ('menina', 'Menina'),
          ('menino', 'Menino'),
          ('mensageiro', 'Mensageiro'),
          ('mestra', 'Mestra'),
          ('mestre', 'Mestre'),
          ('metalurgico', 'Metalurgico'),
          ('militar', 'Militar'),
          ('ministra', 'Ministra'),
          ('ministro', 'Ministro'),
          ('miss', 'Miss'),
          ('missionaria', 'Missionaria'),
          ('missionario', 'Missionario'),
          ('mister', 'Mister'),
          ('monge', 'Monge'),
          ('monsenhor', 'Monsenhor'),
          ('monsieur', 'Monsieur'),
          ('motorista', 'Motorista'),
          ('musicista', 'Musicista'),
          ('musico', 'Musico'),
          ('naturalista', 'Naturalista'),
          ('navegador', 'Navegador'),
          ('neta', 'Neta'),
          ('neto', 'Neto'),
          ('nono', 'Nono'),
          ('nora', 'Nora'),
          ('nossa', 'Nossa'),
          ('nossa senhora', 'NossaSenhora'),
          ('nossa senhora imaculada', 'NossaSenhoraImaculada'),
          ('nosso', 'Nosso'),
          ('nosso senhor', 'NossoSenhor'),
          ('nuncio', 'Nuncio'),
          ('oficial', 'Oficial'),
          ('oficial de justica', 'OficialJustica'),
          ('operaria', 'Operaria'),
          ('operario', 'Operario'),
          ('orador', 'Orador'),
          ('organista', 'Organista'),
          ('ouvidor', 'Ouvidor'),
          ('padre conego', 'PadreConego'),
          ('padre dom', 'PadreDom'),
          ('padres', 'Padres'),
          ('padre santo', 'PadreSanto'),
          ('padroeiro', 'Padroeiro'),
          ('pai', 'Pai'),
          ('paisagista', 'Paisagista'),
          ('papa', 'Papa'),
          ('papa santo', 'PapaSanto'),
          ('papa sao', 'PapaSao'),
          ('paroco', 'Paroco'),
          ('parteira', 'Parteira'),
          ('parteira mae', 'ParteiraMae'),
          ('pastora', 'Pastora'),
          ('patriarca', 'Patriarca'),
          ('patrulheiro', 'Patrulheiro'),
          ('pedestre', 'Pedestre'),
          ('pedreiro', 'Pedreiro'),
          ('perito', 'Perito'),
          ('pescador', 'Pescador'),
          ('pescadora', 'Pescadora'),
          ('pianista', 'Pianista'),
          ('piloto', 'Piloto'),
          ('pintor', 'Pintor'),
          ('pintora', 'Pintora'),
          ('pio', 'Pio'),
          ('pioneira', 'Pioneira'),
          ('pioneiro', 'Pioneiro'),
          ('poceiro', 'Poceiro'),
          ('poeta', 'Poeta'),
          ('poetisa', 'Poetisa'),
          ('policial', 'Policial'),
          ('policial militar', 'PolicialMilitar'),
          ('portuario', 'Portuario'),
          ('praca', 'Praca'),
          ('pracinha', 'Pracinha'),
          ('prefeita', 'Prefeita'),
          ('prefeito', 'Prefeito'),
          ('prefeito coronel', 'PrefeitoCoronel'),
          ('prefeito doutor', 'PrefeitoDoutor'),
          ('presbitero', 'Presbitero'),
          ('presidenta', 'Presidenta'),
          ('presidente', 'Presidente'),
          ('presidente barao', 'PresidenteBarao'),
          ('presidente doutor', 'PresidenteDoutor'),
          ('presidente general', 'PresidenteGeneral'),
          ('presidente marechal', 'PresidenteMarechal'),
          ('prima', 'Prima'),
          ('primeiro ministro', 'PrimeiroMinistro'),
          ('primeiro sargento', 'PrimeiroSargento'),
          ('primeiro sargento pm', 'PrimeiroSargentoPm'),
          ('primeiro tenente', 'PrimeiroTenente'),
          ('primeiro tenente aviador', 'PrimeiroTenenteAviador'),
          ('primo', 'Primo'),
          ('princesa', 'Princesa'),
          ('princesa dona', 'PrincesaDona'),
          ('principe', 'Principe'),
          ('principe dom', 'PrincipeDom'),
          ('prior', 'Prior'),
          ('procurador', 'Procurador'),
          ('procuradora', 'Procuradora'),
          ('professora dona', 'ProfessoraDona'),
          ('professora doutora', 'ProfessoraDoutora'),
          ('professor doutor', 'ProfessorDoutor'),
          ('professor engenheiro', 'ProfessorEngenheiro'),
          ('professor irmao', 'ProfessorIrmao'),
          ('professor padre', 'ProfessorPadre'),
          ('profeta', 'Profeta'),
          ('profetisa', 'Profetisa'),
          ('promotor', 'Promotor'),
          ('promotora', 'Promotora'),
          ('provedor', 'Provedor'),
          ('psicologa', 'Psicologa'),
          ('publicitario', 'Publicitario'),
          ('quimica', 'Quimica'),
          ('quimico', 'Quimico'),
          ('rabi', 'Rabi'),
          ('rabino', 'Rabino'),
          ('radialista', 'Radialista'),
          ('radiotelegrafista', 'Radiotelegrafista'),
          ('rainha', 'Rainha'),
          ('raja', 'Raja'),
          ('regente', 'Regente'),
          ('rei', 'Rei'),
          ('reitor', 'Reitor'),
          ('reitora', 'Reitora'),
          ('remador', 'Remador'),
          ('reporter', 'Reporter'),
          ('reverendissimo', 'Reverendissimo'),
          ('reverendo', 'Reverendo'),
          ('reverendo doutor', 'ReverendoDoutor'),
          ('reverendo professor', 'ReverendoProfessor'),
          ('sacerdote', 'Sacerdote'),
          ('sacerdotisa', 'Sacerdotisa'),
          ('sacristao', 'Sacristao'),
          ('sagrada', 'Sagrada'),
          ('sagrado', 'Sagrado'),
          ('saint', 'Saint'),
          ('san', 'San'),
          ('sanfoneiro', 'Sanfoneiro'),
          ('santa', 'Santa'),
          ('santa madre', 'SantaMadre'),
          ('santissima', 'Santissima'),
          ('santo', 'Santo'),
          ('santos', 'Santos'),
          ('sao', 'Sao'),
          ('sapateiro', 'Sapateiro'),
          ('sargento aviador', 'SargentoAviador'),
          ('sargento da aeronautica', 'SargentoAeronautica'),
          ('sargento expedicionario', 'SargentoExpedicionario'),
          ('sargento mor', 'SargentoMor'),
          ('sargento policia militar', 'SargentoPoliciaMilitar'),
          ('secretaria', 'Secretaria'),
          ('secretario', 'Secretario'),
          ('segundo sargento', 'SegundoSargento'),
          ('segundo tenente', 'SegundoTenente'),
          ('segundo tenente aviador', 'SegundoTenenteAviador'),
          ('seminarista', 'Seminarista'),
          ('senador', 'Senador'),
          ('senadora', 'Senadora'),
          ('senhor', 'Senhor'),
          ('senhora', 'Senhora'),
          ('senhoria', 'Senhoria'),
          ('senhorinha', 'Senhorinha'),
          ('senhorita', 'Senhorita'),
          ('seresteiro', 'Seresteiro'),
          ('seringueiro', 'Seringueiro'),
          ('serralheiro', 'Serralheiro'),
          ('sertanista', 'Sertanista'),
          ('serventuario', 'Serventuario'),
          ('servidor', 'Servidor'),
          ('servidor publico municipal', 'ServidorPublicoMunicipal'),
          ('seu', 'Seu'),
          ('sindicalista', 'Sindicalista'),
          ('sinha', 'Sinha'),
          ('sinho', 'Sinho'),
          ('sir', 'Sir'),
          ('sobrinha', 'Sobrinha'),
          ('sobrinho', 'Sobrinho'),
          ('sociologa', 'Sociologa'),
          ('sociologo', 'Sociologo'),
          ('sogro', 'Sogro'),
          ('soldado', 'Soldado'),
          ('soldado bombeiro', 'SoldadoBombeiro'),
          ('soldado constitucionalista', 'SoldadoConstitucionalista'),
          ('soldado expedicionario', 'SoldadoExpedicionario'),
          ('soldado policia militar', 'SoldadoPoliciaMilitar'),
          ('soror', 'Soror'),
          ('suboficial', 'Suboficial'),
          ('sultana', 'Sultana'),
          ('sultao', 'Sultao'),
          ('supervisor', 'Supervisor'),
          ('tabelia', 'Tabelia'),
          ('tabeliao', 'Tabeliao'),
          ('tabelioa', 'Tabelioa'),
          ('taifeiro', 'Taifeiro'),
          ('taxista', 'Taxista'),
          ('teatrologo', 'Teatrologo'),
          ('tecnico', 'Tecnico'),
          ('tecnico agricola', 'TecnicoAgricola'),
          ('telegrafista', 'Telegrafista'),
          ('tenente aviador', 'TenenteAviador'),
          ('tenente brigadeiro', 'TenenteBrigadeiro'),
          ('tenente coronel', 'TenenteCoronel'),
          ('tenente coronel aviador', 'TenenteCoronelAviador'),
          ('tenente general', 'TenenteGeneral'),
          ('tenente policia militar', 'TenentePoliciaMilitar'),
          ('tenista', 'Tenista'),
          ('tenor', 'Tenor'),
          ('terceiro sargento', 'TerceiroSargento'),
          ('terceiro sargento pm', 'TerceiroSargentoPm'),
          ('tia', 'Tia'),
          ('tio', 'Tio'),
          ('tipografo', 'Tipografo'),
          ('titio', 'Titio'),
          ('topografo', 'Topografo'),
          ('trabalhador', 'Trabalhador'),
          ('tradicionalista', 'Tradicionalista'),
          ('trovador', 'Trovador'),
          ('universitaria', 'Universitaria'),
          ('universitario', 'Universitario'),
          ('vaqueiro', 'Vaqueiro'),
          ('velha', 'Velha'),
          ('velho', 'Velho'),
          ('veneravel', 'Veneravel'),
          ('vereador', 'Vereador'),
          ('vereadora', 'Vereadora'),
          ('vereador doutor', 'VereadorDoutor'),
          ('vereador professor', 'VereadorProfessor'),
          ('veterano', 'Veterano'),
          ('veterinario', 'Veterinario'),
          ('vice', 'Vice'),
          ('vice almirante', 'ViceAlmirante'),
          ('vice governador', 'ViceGovernador'),
          ('vicentino', 'Vicentino'),
          ('vice presidente', 'VicePresidente'),
          ('vice rei', 'ViceRei'),
          ('vigario', 'Vigario'),
          ('vigia', 'Vigia'),
          ('vigilante', 'Vigilante'),
          ('violeiro', 'Violeiro'),
          ('violinista', 'Violinista'),
          ('violonista', 'Violonista'),
          ('virgem', 'Virgem'),
          ('visconde', 'Visconde'),
          ('viscondessa', 'Viscondessa'),
          ('viuva', 'Viuva'),
          ('vo', 'Vo'),
          ('voluntaria', 'Voluntaria'),
          ('voluntario', 'Voluntario'),
          ('voluntarios', 'Voluntarios'),
          ('vovo', 'Vovo');



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

    RETURN v_resultado;
END;
$$;

-----------------------
-- FUNCTIONS : END   --
-----------------------


-- Gera materialized view public.cep_string_padronizada 
   -- Roda em até 1 min
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
     
    -- String Compacta Hierárquica estrita (Bairro limpo via função com parâmetro False)
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
        
        -- Caso C3: Localidade (Bairro/Município limpo sem abreviação de logradouro)
        WHEN t.tipo_cep IN ('LOCALIDADE') 
        THEN SUBSTRING(j.isolabel_ext, 4) || '-' ||
             endereco_to_camel_correios(COALESCE(NULLIF(BTRIM(c.bairro), ''), NULLIF(BTRIM(c.municipio), '')), FALSE)
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
        ELSE 'C1-geral'
    END AS tipo_falta,

    t.cep AS cep_bruto

FROM public.cep_tipologia t
LEFT JOIN public.cep_unificado c 
       ON BTRIM(t.cep::text) = BTRIM(c.cep::text)
LEFT JOIN imported.jurisdiction j 
       ON c.municipio_cod_ibge::bigint = j.cod_ibge::bigint;

-- Índice essencial para performance na string compacta final
CREATE INDEX idx_cep_string_compacta ON public.cep_string_padronizada (string_compacta);





























































////////////////////////////// EXEMPLO DE ENDERECOS - Rodar em demogov ///////////////////////////////////

-- Cria extension
CREATE EXTENSION IF NOT EXISTS dblink;

-- Criar o schema cnefe2022
CREATE SCHEMA IF NOT EXISTS cnefe2022;




-- Cria uma tabela com os endereços completos distintos (Versão Otimizada) : Início --

    -- 1. Cria o índice composto incluindo a coluna modificadora na origem (demogov)
    SELECT dblink_exec(
        'dbname=demogov',
        'CREATE INDEX IF NOT EXISTS idx_ibge_cnefe2022_enderecos_full 
         ON public.ibge_cnefe2022 (cep,nom_tipo_seglogr, nom_titulo_seglogr, nom_seglogr, num_endereco, dsc_modificador) 
         WHERE num_endereco <> ''0'';'
    );
    
    -- 2. Puxa os dados com agrupamento otimizado
    DROP TABLE IF EXISTS cnefe2022.enderecos_completos_distintos;
    CREATE TABLE cnefe2022.enderecos_completos_distintos AS -- Roda em 3 minutos
    SELECT
        cep,
        nom_tipo_seglogr,
        nom_titulo_seglogr,
        nom_seglogr,
        num_endereco,
        CASE 
            WHEN dsc_modificador IN ('A', 'B', 'C') THEN dsc_modificador 
            ELSE NULL 
        END AS dsc_modificador
    FROM dblink(
        'dbname=demogov',
        'SELECT
             cep,
             nom_tipo_seglogr, 
             nom_titulo_seglogr, 
             nom_seglogr, 
             num_endereco,
             dsc_modificador
         FROM public.ibge_cnefe2022 
         WHERE num_endereco <> ''0''
         GROUP BY
             cep,
             nom_tipo_seglogr, 
             nom_titulo_seglogr, 
             nom_seglogr, 
             num_endereco, 
             dsc_modificador'
    ) AS t(
        cep TEXT,
        nom_tipo_seglogr TEXT,
        nom_titulo_seglogr TEXT,
        nom_seglogr TEXT,
        num_endereco TEXT,
        dsc_modificador TEXT
    );
    
    -- 3. Remove o índice temporário do banco de origem (demogov)
    SELECT dblink_exec(
        'dbname=demogov',
        'DROP INDEX IF EXISTS public.idx_ibge_cnefe2022_enderecos_full;'
    );

-- Cria uma tabela com os endereços completos distintos : Fim --

-- Cria índices na tabela base local para acelerar o DISTINCT e o agrupamento
CREATE INDEX IF NOT EXISTS idx_base_tipo_seglogr ON cnefe2022.enderecos_completos_distintos (nom_tipo_seglogr);
CREATE INDEX IF NOT EXISTS idx_base_titulo_seglogr ON cnefe2022.enderecos_completos_distintos (nom_titulo_seglogr);
CREATE INDEX IF NOT EXISTS idx_base_seglogr ON cnefe2022.enderecos_completos_distintos (nom_seglogr);

-- Analisa a tabela para atualizar as estatísticas do planejador do PostgreSQL
ANALYZE cnefe2022.enderecos_completos_distintos;

-- Criar tabela para os tipos de logradouro
DROP MATERIALIZED VIEW IF EXISTS cnefe2022.tipo_seglogr;
CREATE MATERIALIZED VIEW IF NOT EXISTS cnefe2022.tipo_seglogr AS
SELECT DISTINCT 
    nom_tipo_seglogr,
    COALESCE(
        shrink_logradouro_tipo(nom_tipo_seglogr),
        endereco_to_camel_correios(nom_tipo_seglogr, False)
    ) AS nom_tipo_seglogr_strcompacta
FROM cnefe2022.enderecos_completos_distintos
WHERE nom_tipo_seglogr IS NOT NULL;

-- Criar tabela para os títulos de logradouro
DROP MATERIALIZED VIEW IF EXISTS cnefe2022.titulo_seglogr;
CREATE MATERIALIZED VIEW IF NOT EXISTS cnefe2022.titulo_seglogr AS
SELECT DISTINCT 
    nom_titulo_seglogr,
    COALESCE(
        shrink_logradouro_titulo(nom_titulo_seglogr),
        endereco_to_camel_correios(nom_titulo_seglogr, False)
    ) AS nom_titulo_seglogr_strcompacta
FROM cnefe2022.enderecos_completos_distintos
WHERE nom_titulo_seglogr IS NOT NULL;

-- Criar tabela para os nomes de logradouro usando dblink
DROP MATERIALIZED VIEW IF EXISTS cnefe2022.seglogr;
CREATE MATERIALIZED VIEW IF NOT EXISTS cnefe2022.seglogr AS
SELECT DISTINCT 
    nom_seglogr,
    endereco_to_camel_correios(nom_seglogr, False) AS nom_seglogr_strcompacta
FROM cnefe2022.enderecos_completos_distintos
WHERE nom_seglogr IS NOT NULL;

-- Obtem nomes únicos e suas respectivas versões de string compacta
DROP MATERIALIZED VIEW IF EXISTS cnefe2022.logradouros_combinados_compactados;
CREATE MATERIALIZED VIEW cnefe2022.logradouros_combinados_compactados AS
SELECT 
    t.nom_tipo_seglogr,
    tp.nom_tipo_seglogr_strcompacta,
    t.nom_titulo_seglogr,
    tt.nom_titulo_seglogr_strcompacta,
    t.nom_seglogr,
    s.nom_seglogr_strcompacta
FROM (
    SELECT 
        nom_tipo_seglogr,
        nom_titulo_seglogr,
        nom_seglogr
    FROM cnefe2022.enderecos_completos_distintos
    GROUP BY 
        nom_tipo_seglogr,
        nom_titulo_seglogr,
        nom_seglogr
) t
LEFT JOIN cnefe2022.tipo_seglogr tp 
    ON t.nom_tipo_seglogr = tp.nom_tipo_seglogr
LEFT JOIN cnefe2022.titulo_seglogr tt 
    ON t.nom_titulo_seglogr = tt.nom_titulo_seglogr
LEFT JOIN cnefe2022.seglogr s 
    ON t.nom_seglogr = s.nom_seglogr;


-- Cria tabela cep string padronizada
DROP MATERIALIZED VIEW IF EXISTS public.cep_string_padronizada_cnefe;
CREATE MATERIALIZED VIEW IF NOT EXISTS public.cep_string_padronizada_cnefe AS
SELECT 
    -- 1. endereco_postal (Com normalização para remover qualquer espaço duplo)
    REGEXP_REPLACE(
        TRIM(BOTH FROM (
            COALESCE(INITCAP(NULLIF(BTRIM(c.nom_tipo_seglogr), '')), '') || ' ' || 
            COALESCE(INITCAP(NULLIF(BTRIM(c.nom_titulo_seglogr), '')), '') || ' ' || 
            COALESCE(INITCAP(NULLIF(BTRIM(c.nom_seglogr), '')), '') ||
            -- Número e Modificador colados (ex: 6C)
            CASE 
                WHEN NULLIF(BTRIM(c.num_endereco), '') IS NOT NULL AND NULLIF(BTRIM(c.dsc_modificador), '') IS NOT NULL 
                THEN ', ' || c.num_endereco || UPPER(TRIM(c.dsc_modificador))
                WHEN NULLIF(BTRIM(c.num_endereco), '') IS NOT NULL 
                THEN ', ' || c.num_endereco
                ELSE '' 
            END ||
            -- Bairro separado por '•'
            CASE WHEN NULLIF(BTRIM(cu.bairro), '') IS NOT NULL THEN ' • ' || cu.bairro ELSE '' END ||
            CASE WHEN NULLIF(BTRIM(j.name), '') IS NOT NULL THEN ', ' || j.name ELSE '' END ||
            CASE WHEN NULLIF(BTRIM(SPLIT_PART(j.isolabel_ext, '-', 2)), '') IS NOT NULL THEN '/' || SPLIT_PART(j.isolabel_ext, '-', 2) ELSE '' END ||
            ', CEP ' || "left"(c.cep, 5) || '-' || "right"(c.cep, 3)
        )),
        '\s+', ' ' , 'g'
    ) AS endereco_postal,

    -- 2. string_compacta
    (
        SUBSTRING(j.isolabel_ext FROM 4) || '-' || 
        COALESCE(tp.nom_tipo_seglogr_strcompacta, '') ||
        CASE WHEN NULLIF(BTRIM(tt.nom_titulo_seglogr_strcompacta), '') IS NOT NULL THEN '_' || tt.nom_titulo_seglogr_strcompacta ELSE '' END ||
        '_' || COALESCE(s.nom_seglogr_strcompacta, '') ||
        CASE 
            WHEN NULLIF(BTRIM(c.num_endereco), '') IS NOT NULL 
            THEN '~' || REGEXP_REPLACE(c.num_endereco, '^\s*([0-9]+[ABC]?).*', '\1') || 
                 COALESCE(UPPER(NULLIF(BTRIM(c.dsc_modificador), '')), '')
            ELSE '' 
        END
    ) AS string_compacta,

    -- 3. caso 
    'C1'::text AS caso,

    -- 4. tipo_falta
    'C1-geral'::text AS tipo_falta,

    -- 5. cep_bruto
    c.cep AS cep_bruto

FROM cnefe2022.enderecos_completos_distintos c
LEFT JOIN cep_unificado cu ON btrim(c.cep::text) = btrim(cu.cep::text)
LEFT JOIN imported.jurisdiction j ON cu.municipio_cod_ibge::bigint = j.cod_ibge::bigint
LEFT JOIN cnefe2022.tipo_seglogr tp ON c.nom_tipo_seglogr = tp.nom_tipo_seglogr
LEFT JOIN cnefe2022.titulo_seglogr tt ON c.nom_titulo_seglogr = tt.nom_titulo_seglogr
LEFT JOIN cnefe2022.seglogr s ON c.nom_seglogr = s.nom_seglogr;




-- Remove índices após processamento
DROP INDEX IF EXISTS idx_base_tipo_seglogr;
DROP INDEX IF EXISTS idx_base_titulo_seglogr;
DROP INDEX IF EXISTS idx_base_seglogr;























DROP VIEW IF EXISTS public.cnefe_enderecos_processados_exemplo;

CREATE VIEW public.cnefe_enderecos_processados_exemplo AS
SELECT 
    cep,
    
    -- Bairro / Localidade
    NULLIF(BTRIM(dsc_localidade), '') AS bairro,
    
    -- {{tipo_logradouro}}
    NULLIF(BTRIM(nom_tipo_seglogr), '') AS tipo_logradouro,
    
    -- {{tituloenomelogradouro}} (Título + Nome juntos, blindado contra espaços duplos)
    NULLIF(
        REGEXP_REPLACE(
            TRIM(COALESCE(nom_titulo_seglogr, '') || ' ' || COALESCE(nom_seglogr, '')),
            '\s+', ' ', 'g'
        ),
        ''
    ) AS tituloenomelogradouro,
    
    -- Logradouro completo padrão (Tipo + Título + Nome)
    NULLIF(
        REGEXP_REPLACE(
            TRIM(COALESCE(nom_tipo_seglogr, '') || ' ' || COALESCE(nom_titulo_seglogr, '') || ' ' || COALESCE(nom_seglogr, '')),
            '\s+', ' ', 'g'
        ),
        ''
    ) AS logradouro,
    
    -- {{numeroemodificador}} padrão para o endereço postal (ex: 100-A ou apenas 100 se o modificador for nulo)
    NULLIF(
        BTRIM(num_endereco) || 
        CASE 
            WHEN NULLIF(BTRIM(dsc_modificador), '') IS NOT NULL THEN '-' || BTRIM(dsc_modificador)
            ELSE '' 
        END,
        ''
    ) AS numeroemodificador,
    
    -- {{numeroemodificador_compacto}} específico para a string compacta (ex: 100_A ou apenas 100 se o modificador for nulo)
    NULLIF(
        BTRIM(num_endereco) || 
        CASE 
            WHEN NULLIF(BTRIM(dsc_modificador), '') IS NOT NULL THEN '_' || BTRIM(dsc_modificador)
            ELSE '' 
        END,
        ''
    ) AS numeroemodificador_compacto

FROM public.ibge_cnefe2022
WHERE cod_municipio = '4316907'
  AND num_endereco IS NOT NULL
  AND num_endereco <> '0'
GROUP BY cod_municipio,
         cep,
         dsc_localidade,
         nom_tipo_seglogr,
         nom_titulo_seglogr,
         nom_seglogr,
         num_endereco,
         dsc_modificador;

-- Criando índice para performance nos cruzamentos futuros
CREATE INDEX idx_cnefe_proc_cep ON public.cnefe_enderecos_processados (cep);


