-- ============================================================
-- Layer 3: 原始数据层 - 日行情 + 复权因子
-- 
-- 【坑1 除权除息 核心表】：
--   - pre_adj_factor: 前复权因子，前复权价 = close × pre_adj_factor
--   - post_adj_factor: 后复权因子，后复权价 = close × post_adj_factor
--   - 最新交易日复权因子 = 1.0，历史日期的因子逐日前推
--   - 当发生除权除息事件时，所有历史日期的 pre_adj_factor 需乘以调整比例
--   - 复权因子存储在每行中，查询时无需跨表JOIN，性能最优
-- ============================================================

CREATE TABLE IF NOT EXISTS daily_quotes (
    id               BIGSERIAL PRIMARY KEY,
    company_id       INT            NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    trade_date       DATE           NOT NULL,
    open             NUMERIC(14,4),
    high             NUMERIC(14,4),
    low              NUMERIC(14,4),
    close            NUMERIC(14,4),
    pre_close        NUMERIC(14,4),
    volume           BIGINT,
    amount           NUMERIC(20,4),
    change_pct       NUMERIC(10,4),
    turnover_rate    NUMERIC(10,4),
    limit_status     BOOLEAN        DEFAULT FALSE,   -- 涨跌停
    st_status        BOOLEAN        DEFAULT FALSE,   -- ST状态
    suspend_flag     BOOLEAN        DEFAULT FALSE,   -- 停牌标记
    pre_adj_factor   NUMERIC(16,8)  DEFAULT 1.0,     -- 前复权因子
    post_adj_factor  NUMERIC(16,8)  DEFAULT 1.0,     -- 后复权因子
    source_id        INT            NOT NULL REFERENCES data_sources(id),
    created_at       TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
    UNIQUE (company_id, trade_date, source_id)
);

COMMENT ON TABLE daily_quotes IS '日行情数据表——存储每日OHLCV及复权因子，是除权除息解决方案的核心';
COMMENT ON COLUMN daily_quotes.pre_adj_factor IS '前复权因子：前复权收盘价 = close × pre_adj_factor。最新交易日=1.0，发生除权时所有历史因子重算';
COMMENT ON COLUMN daily_quotes.post_adj_factor IS '后复权因子：后复权收盘价 = close × post_adj_factor';
COMMENT ON COLUMN daily_quotes.limit_status IS '是否涨停/跌停（TRUE=触及涨跌停板）';
COMMENT ON COLUMN daily_quotes.st_status IS '是否ST股';
COMMENT ON COLUMN daily_quotes.suspend_flag IS '是否停牌';
COMMENT ON COLUMN daily_quotes.source_id IS '数据来源，多源数据通过 (company_id, trade_date, source_id) 联合唯一约束共存';

-- 性能索引
CREATE INDEX idx_dq_company_date ON daily_quotes(company_id, trade_date);
CREATE INDEX idx_dq_trade_date ON daily_quotes(trade_date);
CREATE INDEX idx_dq_company_source ON daily_quotes(company_id, source_id);
-- BRIN索引适合时间序列顺序写入的大表
CREATE INDEX idx_dq_date_brin ON daily_quotes USING BRIN(trade_date);

-- ============================================================
-- 表: adjustment_events - 除权除息事件审计表
-- 解决【坑1】：独立记录每次除权除息事件，提供审计追踪
-- ============================================================

CREATE TABLE IF NOT EXISTS adjustment_events (
    id                       BIGSERIAL PRIMARY KEY,
    company_id               INT              NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    ex_date                  DATE             NOT NULL,     -- 除权除息日
    event_type               adj_event_type_enum NOT NULL,
    cash_dividend            NUMERIC(14,6),                  -- 每股现金分红（元）
    bonus_share_ratio        NUMERIC(10,6),                  -- 送股比例（如0.5=10送5）
    transfer_share_ratio     NUMERIC(10,6),                  -- 转增比例（如1.0=10转10）
    rights_issue_price       NUMERIC(14,4),                  -- 配股价
    rights_issue_ratio       NUMERIC(10,6),                  -- 配股比例
    adjustment_factor_ratio  NUMERIC(16,12) NOT NULL,        -- 本次调整比例（新因子=旧因子×该值）
    pre_adj_factor_before    NUMERIC(16,8),                  -- 事件前最新交易日的pre_adj_factor快照
    pre_adj_factor_after     NUMERIC(16,8),                  -- 事件后最新交易日的pre_adj_factor快照
    source_id                INT              NOT NULL REFERENCES data_sources(id),
    created_at               TIMESTAMPTZ      NOT NULL DEFAULT NOW(),
    UNIQUE (company_id, ex_date, event_type, source_id)
);

COMMENT ON TABLE adjustment_events IS '除权除息事件表——记录每次影响复权因子的事件，提供完整审计追踪';
COMMENT ON COLUMN adjustment_events.adjustment_factor_ratio IS '本次事件的调整比例。新复权因子 = 旧复权因子 × 该比例。用于批量重算历史pre_adj_factor';
COMMENT ON COLUMN adjustment_events.pre_adj_factor_before IS '事件前快照，用于校验复权因子重算正确性';
COMMENT ON COLUMN adjustment_events.pre_adj_factor_after IS '事件后快照';

CREATE INDEX idx_adj_events_company ON adjustment_events(company_id, ex_date);
