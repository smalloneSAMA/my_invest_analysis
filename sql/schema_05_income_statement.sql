-- ============================================================
-- Layer 3: 原始数据层 - 利润表（宽表）
-- 
-- 【坑3 NULL vs 0】：所有数值字段 DEFAULT NULL
--   分母为NULL时指标结果为NULL，而非错误地除以0
-- ============================================================

CREATE TABLE IF NOT EXISTS income_statement (
    id                       BIGSERIAL PRIMARY KEY,
    company_id               INT             NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    report_date              DATE            NOT NULL,
    announcement_date        DATE,
    report_type              report_type_enum NOT NULL,

    -- 收入与成本
    total_revenue            NUMERIC(20,4),     -- 营业总收入
    operating_revenue        NUMERIC(20,4),     -- 营业收入
    operating_cost           NUMERIC(20,4),     -- 营业成本
    gross_profit             NUMERIC(20,4),     -- 毛利润 = 营收 - 营业成本

    -- 利润层次
    operating_profit         NUMERIC(20,4),     -- 营业利润
    total_profit             NUMERIC(20,4),     -- 利润总额
    net_profit               NUMERIC(20,4),     -- 净利润
    net_profit_parent        NUMERIC(20,4),     -- 归属于母公司股东净利润（PE分母）
    net_profit_deducted      NUMERIC(20,4),     -- 扣除非经常性损益后净利润

    -- 收益明细
    operating_income_net     NUMERIC(20,4),     -- 经营活动净收益
    fair_value_change_income NUMERIC(20,4),     -- 公允价值变动净收益
    interest_expense         NUMERIC(20,4),     -- 利息费用（利息保障倍数分母）

    -- 每股指标（财报披露值）
    basic_eps_disclosed      NUMERIC(14,6),     -- 基本每股收益(披露值)
    diluted_eps_disclosed    NUMERIC(14,6),     -- 稀释每股收益(披露值)

    source_id                INT             NOT NULL REFERENCES data_sources(id),
    created_at               TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    UNIQUE (company_id, report_date, report_type, source_id)
);

COMMENT ON TABLE income_statement IS '利润表（宽表）：一行=一个公司+一个报告期';
COMMENT ON COLUMN income_statement.total_revenue IS '营业总收入：公司主营业务收入合计';
COMMENT ON COLUMN income_statement.operating_revenue IS '营业收入：销售商品或提供服务所得';
COMMENT ON COLUMN income_statement.operating_cost IS '营业成本：与营业收入对应的成本';
COMMENT ON COLUMN income_statement.gross_profit IS '毛利润 = 营业收入 - 营业成本';
COMMENT ON COLUMN income_statement.operating_profit IS '营业利润 = 营业收入 - 营业成本 - 期间费用等';
COMMENT ON COLUMN income_statement.total_profit IS '利润总额 = 营业利润 + 营业外收支';
COMMENT ON COLUMN income_statement.net_profit IS '净利润 = 利润总额 - 所得税';
COMMENT ON COLUMN income_statement.net_profit_parent IS '归母净利润：PE/ROE等核心指标的关键分母';
COMMENT ON COLUMN income_statement.net_profit_deducted IS '扣非净利润：剔除一次性损益后的真实盈利';
COMMENT ON COLUMN income_statement.interest_expense IS '利息费用：用于计算利息保障倍数 = EBIT / 利息费用';
COMMENT ON COLUMN income_statement.basic_eps_disclosed IS '基本每股收益(财报披露值)：可能与自主计算值有差异';
COMMENT ON COLUMN income_statement.diluted_eps_disclosed IS '稀释每股收益(披露值)：考虑潜在稀释因素';

CREATE INDEX idx_is_company_date ON income_statement(company_id, report_date);
CREATE INDEX idx_is_report_date ON income_statement(report_date);
CREATE INDEX idx_is_company_source ON income_statement(company_id, source_id);
