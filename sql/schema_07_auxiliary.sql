-- ============================================================
-- Layer 3: 原始数据层 - 股本、分红、审计意见
-- ============================================================

-- 表: share_capital - 股本历史
CREATE TABLE IF NOT EXISTS share_capital (
    id                 BIGSERIAL PRIMARY KEY,
    company_id         INT             NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    report_date        DATE            NOT NULL,
    total_shares       BIGINT,                         -- 总股本（股）
    float_shares       BIGINT,                         -- 流通股本
    restricted_shares  BIGINT,                         -- 限售股本
    a_shares           BIGINT,                         -- A股股本
    b_shares           BIGINT,                         -- B股股本
    h_shares           BIGINT,                         -- H股股本
    shareholder_count  INT,                            -- 股东总数
    source_id          INT             NOT NULL REFERENCES data_sources(id),
    created_at         TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    UNIQUE (company_id, report_date, source_id)
);

COMMENT ON TABLE share_capital IS '股本与股份数据：按报告期记录股本结构变化';
COMMENT ON COLUMN share_capital.total_shares IS '总股本：用于计算总市值=收盘价×总股本';
COMMENT ON COLUMN share_capital.float_shares IS '流通股本：用于计算流通市值=收盘价×流通股本';
COMMENT ON COLUMN share_capital.restricted_shares IS '限售股本：已发行但尚在限售期的股份';
COMMENT ON COLUMN share_capital.shareholder_count IS '股东总数：报告期末登记在册的股东人数';

CREATE INDEX idx_sc_company_date ON share_capital(company_id, report_date);

-- 表: dividend_records - 分红记录
CREATE TABLE IF NOT EXISTS dividend_records (
    id                    BIGSERIAL PRIMARY KEY,
    company_id            INT             NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    ex_div_date           DATE            NOT NULL,        -- 除权除息日
    plan_announce_date    DATE,                             -- 预案公告日
    cash_div_per_share    NUMERIC(14,6),                    -- 每股现金分红（元）
    stock_div_ratio       NUMERIC(10,6),                    -- 送转股总比例
    total_cash_div        NUMERIC(20,4),                    -- 现金分红总额
    source_id             INT             NOT NULL REFERENCES data_sources(id),
    created_at            TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    UNIQUE (company_id, ex_div_date, source_id)
);

COMMENT ON TABLE dividend_records IS '分红记录表：用于计算股息率、分红融资比、股息支付率等';
COMMENT ON COLUMN dividend_records.cash_div_per_share IS '每股现金分红：用于计算股息率 = 近一年累计分红 / 股价';
COMMENT ON COLUMN dividend_records.total_cash_div IS '现金分红总额：用于股息支付率 = 分红总额 / 归母净利润';

CREATE INDEX idx_div_company_date ON dividend_records(company_id, ex_div_date);

-- 表: audit_opinions - 审计意见
CREATE TABLE IF NOT EXISTS audit_opinions (
    id             BIGSERIAL PRIMARY KEY,
    company_id     INT                NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    report_date    DATE               NOT NULL,
    report_type    report_type_enum   NOT NULL,
    opinion_type   audit_opinion_enum NOT NULL,
    auditor        VARCHAR(200),                       -- 审计机构名称
    source_id      INT                NOT NULL REFERENCES data_sources(id),
    created_at     TIMESTAMPTZ        NOT NULL DEFAULT NOW(),
    UNIQUE (company_id, report_date, report_type, source_id)
);

COMMENT ON TABLE audit_opinions IS '审计意见表——排雷核心：非标准意见即回避';
COMMENT ON COLUMN audit_opinions.opinion_type IS '审计意见类型：标准无保留/带强调事项段/保留/否定/无法表示';
COMMENT ON COLUMN audit_opinions.auditor IS '审计机构名称';

CREATE INDEX idx_ao_company_date ON audit_opinions(company_id, report_date);
