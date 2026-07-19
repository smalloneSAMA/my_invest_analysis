-- ============================================================
-- Layer 4: 衍生数据层 - 日频衍生指标（物化存储）
-- 估值指标 + 市场情绪指标
-- 每天收盘后由业务层批量刷新
-- ============================================================

CREATE TABLE IF NOT EXISTS derived_metrics_daily (
    id                      BIGSERIAL PRIMARY KEY,
    company_id              INT           NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    trade_date              DATE          NOT NULL,

    -- 估值指标 (Category 7)
    total_mv                NUMERIC(20,4),      -- 总市值 = close × total_shares
    float_mv                NUMERIC(20,4),      -- 流通市值 = close × float_shares
    pe                      NUMERIC(14,4),      -- 市盈率（静态）= 总市值 / 归母净利润
    pe_ttm                  NUMERIC(14,4),      -- 滚动市盈率 = 总市值 / 近12月归母净利润
    pb                      NUMERIC(14,4),      -- 市净率 = 总市值 / 归母权益
    ps                      NUMERIC(14,4),      -- 市销率 = 总市值 / 营业总收入(TTM)
    pcf                     NUMERIC(14,4),      -- 市现率 = 总市值 / 经营现金流(TTM)
    peg                     NUMERIC(14,4),      -- PEG = PE-TTM / 归母净利润增速×100
    dividend_yield          NUMERIC(14,6),      -- 股息率 = 近一年分红总额 / 总市值
    ev_ebitda               NUMERIC(14,4),      -- EV/EBITDA

    -- 市场情绪指标 (Category 15)
    pe_history_percentile   NUMERIC(10,4),      -- PE历史分位点（过去N年）
    pb_history_percentile   NUMERIC(10,4),      -- PB历史分位点
    a_share_risk_premium    NUMERIC(10,4),      -- A股风险溢价 = (1/PE) - 10年国债收益率

    created_at              TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    UNIQUE (company_id, trade_date)
);

COMMENT ON TABLE derived_metrics_daily IS '日频衍生指标表（物化存储）：估值指标+市场情绪，每日收盘后全量刷新';
COMMENT ON COLUMN derived_metrics_daily.pe IS '静态市盈率：总市值/最新年报归母净利润。NULL=净利润为负或缺失';
COMMENT ON COLUMN derived_metrics_daily.pe_ttm IS '滚动市盈率：总市值/近12月归母净利润合计，比静态PE更及时';
COMMENT ON COLUMN derived_metrics_daily.pb IS '市净率：总市值/归母股东权益。银行业核心估值指标';
COMMENT ON COLUMN derived_metrics_daily.peg IS 'PEG = PE-TTM / (净利润增速×100)，<1表示可能被低估';
COMMENT ON COLUMN derived_metrics_daily.dividend_yield IS '股息率：近一年现金分红/总市值，红利策略核心指标';
COMMENT ON COLUMN derived_metrics_daily.pe_history_percentile IS 'PE历史分位点：当前PE在历史区间的百分位，>80%=高估，<20%=低估';

CREATE INDEX idx_dmd_company_date ON derived_metrics_daily(company_id, trade_date);
CREATE INDEX idx_dmd_trade_date ON derived_metrics_daily(trade_date);
