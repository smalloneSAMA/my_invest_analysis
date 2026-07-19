-- ============================================================
-- Layer 3: 原始数据层 - 现金流量表（宽表）
-- ============================================================

CREATE TABLE IF NOT EXISTS cash_flow_statement (
    id                     BIGSERIAL PRIMARY KEY,
    company_id             INT             NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    report_date            DATE            NOT NULL,
    announcement_date      DATE,
    report_type            report_type_enum NOT NULL,

    -- 三大现金流
    cf_operating           NUMERIC(20,4),      -- 经营活动产生的现金流量净额
    cf_investing           NUMERIC(20,4),      -- 投资活动产生的现金流量净额
    cf_financing           NUMERIC(20,4),      -- 筹资活动产生的现金流量净额
    cf_net_increase        NUMERIC(20,4),      -- 现金及现金等价物净增加额

    -- 每股与资本支出
    cf_operating_per_share NUMERIC(14,6),      -- 每股经营活动现金流(披露值)
    capex                  NUMERIC(20,4),      -- 资本支出（购建固定资产、无形资产等）

    source_id              INT             NOT NULL REFERENCES data_sources(id),
    created_at             TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    UNIQUE (company_id, report_date, report_type, source_id)
);

COMMENT ON TABLE cash_flow_statement IS '现金流量表（宽表）：一行=一个公司+一个报告期';
COMMENT ON COLUMN cash_flow_statement.cf_operating IS '经营活动现金流量净额：自由现金流计算基础，PCF分母';
COMMENT ON COLUMN cash_flow_statement.cf_investing IS '投资活动现金流量净额';
COMMENT ON COLUMN cash_flow_statement.cf_financing IS '筹资活动现金流量净额';
COMMENT ON COLUMN cash_flow_statement.cf_net_increase IS '现金及等价物净增加额';
COMMENT ON COLUMN cash_flow_statement.cf_operating_per_share IS '每股经营现金流(披露值)';
COMMENT ON COLUMN cash_flow_statement.capex IS '资本支出：用于计算自由现金流 FCF = 经营现金流 - 资本支出';

CREATE INDEX idx_cf_company_date ON cash_flow_statement(company_id, report_date);
CREATE INDEX idx_cf_report_date ON cash_flow_statement(report_date);
CREATE INDEX idx_cf_company_source ON cash_flow_statement(company_id, source_id);
