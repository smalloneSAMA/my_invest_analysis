-- ============================================================
-- Layer 2: 主数据层 - 公司基本信息
-- ============================================================

CREATE TABLE IF NOT EXISTS companies (
    id                   SERIAL PRIMARY KEY,
    ts_code              VARCHAR(20)     NOT NULL UNIQUE,
    symbol               VARCHAR(10)     NOT NULL,
    name                 VARCHAR(50)     NOT NULL,
    full_name            VARCHAR(200),
    exchange             exchange_enum   NOT NULL,
    industry_sw_l1       VARCHAR(100),
    industry_sw_l2       VARCHAR(100),
    list_board           list_board_enum,
    list_date            DATE,
    register_address     VARCHAR(500),
    office_address       VARCHAR(500),
    legal_representative VARCHAR(100),
    main_business        TEXT,
    employees            INT,
    is_active            BOOLEAN         NOT NULL DEFAULT TRUE,
    is_listed            BOOLEAN         NOT NULL DEFAULT TRUE,
    source_id            INT             NOT NULL REFERENCES data_sources(id),
    created_at           TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at           TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE companies IS '公司基本信息表（公司身份标签）';
COMMENT ON COLUMN companies.ts_code IS '证券代码(交易所后缀)，如 000001.SZ / 600000.SH';
COMMENT ON COLUMN companies.symbol IS '纯数字代码，如 000001';
COMMENT ON COLUMN companies.name IS '证券简称';
COMMENT ON COLUMN companies.full_name IS '公司法定全称';
COMMENT ON COLUMN companies.exchange IS '交易所：SH=上海 / SZ=深圳 / BJ=北交所';
COMMENT ON COLUMN companies.industry_sw_l1 IS '申万一级行业分类';
COMMENT ON COLUMN companies.industry_sw_l2 IS '申万二级行业分类';
COMMENT ON COLUMN companies.list_board IS '上市板块';
COMMENT ON COLUMN companies.is_active IS '是否仍存续（退市=false）';
COMMENT ON COLUMN companies.is_listed IS '当前是否仍在交易中';
COMMENT ON COLUMN companies.source_id IS '数据来源，关联data_sources表';

CREATE INDEX idx_companies_industry_l1 ON companies(industry_sw_l1);
CREATE INDEX idx_companies_symbol ON companies(symbol);
CREATE INDEX idx_companies_exchange ON companies(exchange);
