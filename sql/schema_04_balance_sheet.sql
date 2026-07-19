-- ============================================================
-- Layer 3: 原始数据层 - 资产负债表（宽表）
-- 
-- 【坑3 NULL vs 0】：所有数值字段 DEFAULT NULL
--   业务层 safe_divide(a, b) 函数：b IS NULL OR b=0 → RETURN NULL
--   不会因 NULL 被误判为 0 而导致 ROE/ROA 等指标失真
-- ============================================================

CREATE TABLE IF NOT EXISTS balance_sheet (
    id                    BIGSERIAL PRIMARY KEY,
    company_id            INT             NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    report_date           DATE            NOT NULL,
    announcement_date     DATE,
    report_type           report_type_enum NOT NULL,

    -- 资产类
    total_assets          NUMERIC(20,4),
    current_assets        NUMERIC(20,4),
    non_current_assets    NUMERIC(20,4),
    cash_and_equivalents  NUMERIC(20,4),
    accounts_receivable   NUMERIC(20,4),
    inventory             NUMERIC(20,4),
    fixed_assets          NUMERIC(20,4),
    goodwill              NUMERIC(20,4),

    -- 负债类
    total_liabilities     NUMERIC(20,4),
    current_liabilities   NUMERIC(20,4),
    non_current_liabilities NUMERIC(20,4),
    short_term_borrowings NUMERIC(20,4),
    long_term_borrowings  NUMERIC(20,4),
    accounts_payable      NUMERIC(20,4),

    -- 权益类
    total_equity          NUMERIC(20,4),
    equity_parent         NUMERIC(20,4),      -- 归属于母公司股东权益
    capital_reserve       NUMERIC(20,4),      -- 资本公积
    surplus_reserve       NUMERIC(20,4),      -- 盈余公积
    undistributed_profit  NUMERIC(20,4),      -- 未分配利润

    -- 排雷相关
    impairment_loss_assets NUMERIC(20,4),     -- 资产减值损失（部分公司放在BS附注）

    source_id             INT             NOT NULL REFERENCES data_sources(id),
    created_at            TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    UNIQUE (company_id, report_date, report_type, source_id)
);

COMMENT ON TABLE balance_sheet IS '资产负债表（宽表）：一行=一个公司+一个报告期，所有科目作为列';
COMMENT ON COLUMN balance_sheet.total_assets IS '总资产';
COMMENT ON COLUMN balance_sheet.current_assets IS '流动资产';
COMMENT ON COLUMN balance_sheet.non_current_assets IS '非流动资产';
COMMENT ON COLUMN balance_sheet.cash_and_equivalents IS '货币资金 = 现金及银行存款等';
COMMENT ON COLUMN balance_sheet.accounts_receivable IS '应收账款：已销售未收回的货款';
COMMENT ON COLUMN balance_sheet.inventory IS '存货：库存商品、原材料等';
COMMENT ON COLUMN balance_sheet.fixed_assets IS '固定资产：房屋、机器设备等长期资产';
COMMENT ON COLUMN balance_sheet.goodwill IS '商誉：并购溢价，减值风险核心关注指标';
COMMENT ON COLUMN balance_sheet.total_liabilities IS '总负债';
COMMENT ON COLUMN balance_sheet.current_liabilities IS '流动负债：一年内到期的负债';
COMMENT ON COLUMN balance_sheet.non_current_liabilities IS '非流动负债：一年以上到期的负债';
COMMENT ON COLUMN balance_sheet.short_term_borrowings IS '短期借款：一年内到期的银行借款';
COMMENT ON COLUMN balance_sheet.long_term_borrowings IS '长期借款：一年以上到期的银行借款';
COMMENT ON COLUMN balance_sheet.accounts_payable IS '应付账款：已采购未支付的货款';
COMMENT ON COLUMN balance_sheet.total_equity IS '所有者权益（股东权益）= 总资产 - 总负债';
COMMENT ON COLUMN balance_sheet.equity_parent IS '归属于母公司股东权益：ROE分母、PB分母';
COMMENT ON COLUMN balance_sheet.capital_reserve IS '资本公积：股本溢价等资本性公积';
COMMENT ON COLUMN balance_sheet.surplus_reserve IS '盈余公积：从净利润中提取的法定/任意公积';
COMMENT ON COLUMN balance_sheet.undistributed_profit IS '未分配利润：累计未分配的净利润';
COMMENT ON COLUMN balance_sheet.impairment_loss_assets IS '资产减值损失：用于计算 资产减值损失/净利润 排雷指标';

CREATE INDEX idx_bs_company_date ON balance_sheet(company_id, report_date);
CREATE INDEX idx_bs_report_date ON balance_sheet(report_date);
CREATE INDEX idx_bs_company_source ON balance_sheet(company_id, source_id);
