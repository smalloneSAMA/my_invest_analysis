-- ============================================================
-- Layer 4: 衍生数据层 - 财报周期衍生指标（物化存储）
-- 盈利能力 + 营运能力 + 偿债与资本结构 + 现金流质量 + 排雷
-- 当新财报数据入库后由业务层增量刷新
-- ============================================================

CREATE TABLE IF NOT EXISTS derived_metrics_financial (
    id                       BIGSERIAL PRIMARY KEY,
    company_id               INT               NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    report_date              DATE              NOT NULL,
    report_type              report_type_enum  NOT NULL,

    -- 盈利能力指标 (Category 8)
    roe                      NUMERIC(14,6),     -- 净资产收益率 = 归母净利润/归母权益(加权)
    roa                      NUMERIC(14,6),     -- 总资产收益率 = 净利润/总资产
    roic                     NUMERIC(14,6),     -- 投入资本回报率
    gross_margin             NUMERIC(14,6),     -- 毛利率 = (营收-营业成本)/营收
    net_margin               NUMERIC(14,6),     -- 净利率 = 净利润/营收
    operating_margin         NUMERIC(14,6),     -- 营业利润率 = 营业利润/营收
    deducted_net_margin      NUMERIC(14,6),     -- 扣非净利率 = 扣非净利润/营收
    basic_eps_calculated     NUMERIC(14,6),     -- 基本每股收益(计算值) = 归母净利润/总股本

    -- 营运能力指标 (Category 9)
    total_asset_turnover     NUMERIC(14,6),     -- 总资产周转率
    ar_turnover              NUMERIC(14,6),     -- 应收账款周转率
    inventory_turnover       NUMERIC(14,6),     -- 存货周转率
    fixed_asset_turnover     NUMERIC(14,6),     -- 固定资产周转率
    ar_turnover_days         NUMERIC(14,4),     -- 应收账款周转天数 = 365/应收账款周转率
    inventory_turnover_days  NUMERIC(14,4),     -- 存货周转天数 = 365/存货周转率

    -- 偿债与资本结构 (Category 10)
    debt_ratio               NUMERIC(14,6),     -- 资产负债率 = 总负债/总资产
    equity_multiplier        NUMERIC(14,6),     -- 权益乘数 = 总资产/归母权益
    current_ratio            NUMERIC(14,6),     -- 流动比率 = 流动资产/流动负债
    quick_ratio              NUMERIC(14,6),     -- 速动比率 = (流动资产-存货)/流动负债
    interest_coverage        NUMERIC(14,6),     -- 利息保障倍数 = EBIT/利息费用
    interest_bearing_debt_ratio NUMERIC(14,6),  -- 带息负债比率

    -- 现金流质量指标 (Category 12)
    net_profit_cash_ratio    NUMERIC(14,6),     -- 净现比 = 经营现金流/净利润
    sales_cash_ratio         NUMERIC(14,6),     -- 收现比 = 经营现金流/营业收入
    fcf                      NUMERIC(20,4),     -- 自由现金流 = 经营现金流 - 资本支出
    fcf_to_revenue           NUMERIC(14,6),     -- FCF/营业收入
    capex_to_ocf             NUMERIC(14,6),     -- 资本支出/经营现金流

    -- 排雷指标 (Category 13)
    goodwill_to_equity       NUMERIC(14,6),     -- 商誉/净资产：>30%高度警惕
    ar_to_revenue_ttm        NUMERIC(14,6),     -- 应收账款/营业收入(TTM)
    inventory_to_assets      NUMERIC(14,6),     -- 存货/总资产
    impairment_to_profit     NUMERIC(14,6),     -- 资产减值损失/净利润

    -- 股东回报指标 (Category 14)
    dividend_payout_ratio    NUMERIC(14,6),     -- 股息支付率 = 现金分红/归母净利润

    created_at               TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    UNIQUE (company_id, report_date, report_type)
);

COMMENT ON TABLE derived_metrics_financial IS '财报周期衍生指标表（物化存储）：盈利能力/营运/偿债/现金流质量/排雷/股东回报';
COMMENT ON COLUMN derived_metrics_financial.roe IS 'ROE净资产收益率：巴菲特最看重的指标，长期>15%为优秀。NULL=分母或分子为NULL/0';
COMMENT ON COLUMN derived_metrics_financial.roa IS 'ROA总资产收益率：衡量总资产赚钱效率';
COMMENT ON COLUMN derived_metrics_financial.roic IS 'ROIC投入资本回报率：剔除杠杆干扰后的核心业务真实回报';
COMMENT ON COLUMN derived_metrics_financial.gross_margin IS '毛利率：反映产品定价权和护城河宽度';
COMMENT ON COLUMN derived_metrics_financial.net_margin IS '净利率：每元收入最终留下多少纯利润';
COMMENT ON COLUMN derived_metrics_financial.debt_ratio IS '资产负债率：>70%需高度警惕财务风险';
COMMENT ON COLUMN derived_metrics_financial.current_ratio IS '流动比率：短期偿债能力，>1较安全';
COMMENT ON COLUMN derived_metrics_financial.quick_ratio IS '速动比率：更保守的短期偿债能力，剔除存货';
COMMENT ON COLUMN derived_metrics_financial.interest_coverage IS '利息保障倍数：<3倍为警示信号';
COMMENT ON COLUMN derived_metrics_financial.net_profit_cash_ratio IS '净现比：>1表示利润是真金白银，<0.5需警惕';
COMMENT ON COLUMN derived_metrics_financial.sales_cash_ratio IS '收现比：每元营收收回的现金，>0.8合格，>1优秀';
COMMENT ON COLUMN derived_metrics_financial.fcf IS '自由现金流：真正可自由支配的现金，正数且持续增长为佳';
COMMENT ON COLUMN derived_metrics_financial.goodwill_to_equity IS '商誉/净资产：A股最大暗雷，>30%高度警惕商誉减值风险';
COMMENT ON COLUMN derived_metrics_financial.dividend_payout_ratio IS '股息支付率：赚100元分多少，30%-70%较为合理';

CREATE INDEX idx_dmf_company_date ON derived_metrics_financial(company_id, report_date);
CREATE INDEX idx_dmf_report_date ON derived_metrics_financial(report_date);
