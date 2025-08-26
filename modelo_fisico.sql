-- ======================================
--  PRIMA FACIE JOALHERIA - PostgreSQL
--  Modelo Lógico (corrigido)
-- ======================================

-- Limpeza opcional (cuidado em produção)
DROP TABLE IF EXISTS venda_item       CASCADE;
DROP TABLE IF EXISTS venda            CASCADE;
DROP TABLE IF EXISTS consumo_insumo   CASCADE;
DROP TABLE IF EXISTS etapa_producao   CASCADE;
DROP TABLE IF EXISTS ordem_servico    CASCADE;
DROP TABLE IF EXISTS composicao       CASCADE;
DROP TABLE IF EXISTS joia             CASCADE;
DROP TABLE IF EXISTS lote_insumo      CASCADE;
DROP TABLE IF EXISTS material         CASCADE;
DROP TABLE IF EXISTS fornecedor       CASCADE;
DROP TABLE IF EXISTS cliente          CASCADE;

-- ========== TABELAS BÁSICAS ==========

CREATE TABLE fornecedor (
  id_fornecedor   SERIAL PRIMARY KEY,
  nome            VARCHAR(100) NOT NULL,
  contato         VARCHAR(120)
);

CREATE TABLE cliente (
  id_cliente      SERIAL PRIMARY KEY,
  nome            VARCHAR(120) NOT NULL,
  contato         VARCHAR(120)
);

CREATE TABLE material (
  id_material     SERIAL PRIMARY KEY,
  tipo            VARCHAR(10)  NOT NULL,          -- Metal | Pedra
  nome            VARCHAR(100) NOT NULL,
  pureza_quilates NUMERIC(5,2),
  unidade         VARCHAR(5)   NOT NULL,          -- g | ct | un
  custo_unit      NUMERIC(12,2) NOT NULL,
  id_fornecedor   INTEGER       NOT NULL REFERENCES fornecedor(id_fornecedor)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT ck_material_tipo      CHECK (tipo IN ('Metal','Pedra')),
  CONSTRAINT ck_material_unidade   CHECK (unidade IN ('g','ct','un')),
  CONSTRAINT ck_material_custo     CHECK (custo_unit >= 0)
);

CREATE TABLE lote_insumo (
  id_lote         SERIAL PRIMARY KEY,
  id_material     INTEGER NOT NULL REFERENCES material(id_material)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  data_entrada    DATE    NOT NULL DEFAULT CURRENT_DATE,
  qtd_inicial     NUMERIC(14,4) NOT NULL,
  qtd_atual       NUMERIC(14,4) NOT NULL,
  custo_unit_lote NUMERIC(12,2) NOT NULL,
  CONSTRAINT ck_lote_qtd_inicial  CHECK (qtd_inicial >= 0),
  CONSTRAINT ck_lote_qtd_atual    CHECK (qtd_atual   >= 0),
  CONSTRAINT ck_lote_custo        CHECK (custo_unit_lote >= 0)
);

-- ========== PRODUTO (JOIA) ==========

CREATE TABLE joia (
  id_joia         SERIAL PRIMARY KEY,
  sku             VARCHAR(30) UNIQUE,
  categoria       VARCHAR(40)  NOT NULL,
  peso_final      NUMERIC(10,3),
  custo_total     NUMERIC(12,2),
  preco_sugerido  NUMERIC(12,2),
  descricao       VARCHAR(200) NOT NULL,
  CONSTRAINT ck_joia_peso    CHECK (peso_final    IS NULL OR peso_final >= 0),
  CONSTRAINT ck_joia_custo   CHECK (custo_total   IS NULL OR custo_total >= 0),
  CONSTRAINT ck_joia_preco   CHECK (preco_sugerido IS NULL OR preco_sugerido >= 0)
);

-- Relação N:N Joia x Material por tabela associativa
CREATE TABLE composicao (
  id_composicao   SERIAL PRIMARY KEY,
  id_joia         INTEGER NOT NULL REFERENCES joia(id_joia)
    ON UPDATE CASCADE ON DELETE CASCADE,
  id_material     INTEGER NOT NULL REFERENCES material(id_material)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  qtd_planejada   NUMERIC(12,4) NOT NULL,
  CONSTRAINT uq_composicao UNIQUE (id_joia, id_material),
  CONSTRAINT ck_comp_qtd CHECK (qtd_planejada > 0)
);

-- ========== PRODUÇÃO ==========

CREATE TABLE ordem_servico (
  id_os           SERIAL PRIMARY KEY,
  tipo            VARCHAR(20) NOT NULL,     -- linha | personalizada
  id_cliente      INTEGER REFERENCES cliente(id_cliente)
    ON UPDATE CASCADE ON DELETE SET NULL,   -- pode ser NULL para peça de linha
  id_joia         INTEGER NOT NULL REFERENCES joia(id_joia)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  data_abertura   DATE NOT NULL DEFAULT CURRENT_DATE,
  status          VARCHAR(20) NOT NULL DEFAULT 'aberta',  -- aberta | em_producao | concluida
  CONSTRAINT ck_os_tipo   CHECK (tipo IN ('linha','personalizada')),
  CONSTRAINT ck_os_status CHECK (status IN ('aberta','em_producao','concluida'))
);

CREATE TABLE etapa_producao (
  id_etapa        SERIAL PRIMARY KEY,
  id_os           INTEGER NOT NULL REFERENCES ordem_servico(id_os)
    ON UPDATE CASCADE ON DELETE CASCADE,
  nome_etapa      VARCHAR(20) NOT NULL,     -- Fundicao | Modelagem | Soldagem | Cravacao | Polimento
  inicio          TIMESTAMP,
  fim             TIMESTAMP,
  responsavel     VARCHAR(80),
  CONSTRAINT ck_etapa_nome CHECK (nome_etapa IN ('Fundicao','Modelagem','Soldagem','Cravacao','Polimento'))
);

CREATE TABLE consumo_insumo (
  id_consumo      SERIAL PRIMARY KEY,
  id_etapa        INTEGER NOT NULL REFERENCES etapa_producao(id_etapa)
    ON UPDATE CASCADE ON DELETE CASCADE,
  id_lote         INTEGER NOT NULL REFERENCES lote_insumo(id_lote)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  id_material     INTEGER NOT NULL REFERENCES material(id_material)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  qtd_consumida   NUMERIC(14,4) NOT NULL,
  perda           NUMERIC(12,4) NOT NULL DEFAULT 0,
  obs             VARCHAR(200),
  CONSTRAINT ck_cons_qtd  CHECK (qtd_consumida > 0),
  CONSTRAINT ck_cons_perda CHECK (perda >= 0)
);

-- ========== VENDAS ==========

CREATE TABLE venda (
  id_venda        SERIAL PRIMARY KEY,
  id_cliente      INTEGER NOT NULL REFERENCES cliente(id_cliente)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  data            TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  valor_total     NUMERIC(12,2) NOT NULL,
  forma_pagto     VARCHAR(20),              -- PIX | Cartao | Dinheiro
  CONSTRAINT ck_venda_valor CHECK (valor_total >= 0)
);

CREATE TABLE venda_item (
  id_item         SERIAL PRIMARY KEY,
  id_venda        INTEGER NOT NULL REFERENCES venda(id_venda)
    ON UPDATE CASCADE ON DELETE CASCADE,
  id_joia         INTEGER NOT NULL REFERENCES joia(id_joia)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  qtd             INTEGER NOT NULL,
  preco_unit      NUMERIC(12,2) NOT NULL,
  CONSTRAINT ck_item_qtd   CHECK (qtd > 0),
  CONSTRAINT ck_item_preco CHECK (preco_unit >= 0)
);

-- Índices úteis em FKs (melhoram performance)
CREATE INDEX ix_material_fornecedor   ON material(id_fornecedor);
CREATE INDEX ix_lote_material         ON lote_insumo(id_material);
CREATE INDEX ix_comp_joia             ON composicao(id_joia);
CREATE INDEX ix_comp_material         ON composicao(id_material);
CREATE INDEX ix_os_cliente            ON ordem_servico(id_cliente);
CREATE INDEX ix_os_joia               ON ordem_servico(id_joia);
CREATE INDEX ix_etapa_os              ON etapa_producao(id_os);
CREATE INDEX ix_consumo_etapa         ON consumo_insumo(id_etapa);
CREATE INDEX ix_consumo_lote          ON consumo_insumo(id_lote);
CREATE INDEX ix_consumo_material      ON consumo_insumo(id_material);
CREATE INDEX ix_venda_cliente         ON venda(id_cliente);
CREATE INDEX ix_item_venda            ON venda_item(id_venda);
CREATE INDEX ix_item_joia             ON venda_item(id_joia);
