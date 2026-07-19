-- ============================================================
-- Layer 4: 衍生数据层 - 成长性指标（物化存储）
-- Category 11
-- ============================================================

CREATE TABLE IF NOT EXISTS derived_metrics_growth (
    id                       BIGSERIAL PRIMARY KEY,
    company_id               INT               NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    report_date              DATE              NOT NULL,
    report_type              report_type_enum  NOT NULL,

    -- 成长性指标 (Category 11)
    revenue_yoy              NUMERIC(14,6),     -- 营收同比增长率
    net_profit_yoy           NUMERIC(14,6),     -- 归母净利润同比增长率
    deducted_net_profit_yoy  NUMERIC(14,6),     -- 扣非净利润同比增长率
    equity_yoy               NUMERIC(14,6),     -- 净资产增长率
    qoq_net_profit           NUMERIC(14,6),     -- 单季净利润环比增长率

    created_at               TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    UNIQUE (company_id, report_date, report_type)
);

COMMENT ON TABLE derived_metrics_growth IS '成长性指标表（物化存储）：同比增长率与环比增长率';
COMMENT ON COLUMN derived_metrics_growth.revenue_yoy IS '营收同比增长率：(本期营收-上年同期)/上年同期，反映业务规模扩张速度';
COMMENT ON COLUMN derived_metrics_growth.net_profit_yoy IS '归母净利润同比增长率：盈利增长核心指标，PEG计算的关键输入';
COMMENT ON COLUMN derived_metrics_growth.deducted_net_profit_yoy IS '扣非净利润同比增长率：剔除一次性损益后的真实增速';
COMMENT ON COLUMN derived_metrics_growth.equity_yoy IS '净资产增长率：净资产积累速度';
COMMENT ON COLUMN derived_metrics_growth.qoq_net_profit IS '单季净利润环比增长率：剔除基数效应的单季景气趋势指标';

CREATE INDEX idx_dmg_company_date ON derived_metrics_growth(company_id, report_date);
