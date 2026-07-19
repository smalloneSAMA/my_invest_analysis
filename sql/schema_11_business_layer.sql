-- ============================================================
-- 业务层基础设施：安全函数 + 多源优先级视图 + 复权视图
-- ============================================================

-- ============================================================
-- 【坑3 NULL vs 0 核心解决函数】
-- safe_divide：安全除法，任何操作数为 NULL 或除数为 0 时返回 NULL
-- 确保 ROE/ROA 等指标不会因 NULL 被误判为 0 而导致失真
-- ============================================================

CREATE OR REPLACE FUNCTION safe_divide(
    numerator   NUMERIC,
    denominator NUMERIC
) RETURNS NUMERIC
    LANGUAGE sql
    IMMUTABLE
    RETURNS NULL ON NULL INPUT
AS $$
    SELECT CASE
        WHEN denominator IS NULL OR denominator = 0 THEN NULL
        ELSE numerator / denominator
    END;
$$;

COMMENT ON FUNCTION safe_divide(NUMERIC, NUMERIC) IS 
'安全除法函数——解决NULL vs 0语义混淆。
 任何操作数为NULL → 返回NULL；
 分母=0 → 返回NULL（而非除零错误）；
 结果可安全用于 ROE/ROA/PE 等指标计算。';

-- 重载版本：指定精度
CREATE OR REPLACE FUNCTION safe_divide(
    numerator   NUMERIC,
    denominator NUMERIC,
    scale_out   INT
) RETURNS NUMERIC
    LANGUAGE sql
    IMMUTABLE
    RETURNS NULL ON NULL INPUT
AS $$
    SELECT CASE
        WHEN denominator IS NULL OR denominator = 0 THEN NULL
        ELSE ROUND(numerator / denominator, scale_out)
    END;
$$;

-- ============================================================
-- 【坑2 多数据源冲突 核心解决视图】
-- v_priority_data：自动按优先级选取最优数据源的数据
-- 同一 (company, date) 下，只返回 priority 最高的 source 的数据
-- ============================================================

CREATE OR REPLACE VIEW v_daily_quotes_priority AS
SELECT DISTINCT ON (dq.company_id, dq.trade_date)
    dq.*,
    dsp.priority AS source_priority
FROM daily_quotes dq
JOIN data_source_priority dsp 
    ON dsp.source_id = dq.source_id 
    AND dsp.data_category = 'daily_quote'
WHERE dsp.priority IS NOT NULL
ORDER BY dq.company_id, dq.trade_date, dsp.priority ASC;

COMMENT ON VIEW v_daily_quotes_priority IS
'多源优先级视图：自动为每个(公司,交易日)选取优先级最高(priority最小)的数据源。
 解决【坑2多数据源冲突】——不同源数据互不覆盖，业务层统一取TOP1。';

-- 财报优先级视图
CREATE OR REPLACE VIEW v_balance_sheet_priority AS
SELECT DISTINCT ON (bs.company_id, bs.report_date, bs.report_type)
    bs.*,
    dsp.priority AS source_priority
FROM balance_sheet bs
JOIN data_source_priority dsp
    ON dsp.source_id = bs.source_id
    AND dsp.data_category = 'balance_sheet'
WHERE dsp.priority IS NOT NULL
ORDER BY bs.company_id, bs.report_date, bs.report_type, dsp.priority ASC;

-- ============================================================
-- 【坑1 除权除息 核心解决视图】
-- v_daily_quotes_adjusted：自动返回前复权 OHLCV
-- 业务层直接用此视图查询，无需手动处理复权因子
-- ============================================================

CREATE OR REPLACE VIEW v_daily_quotes_adjusted AS
SELECT
    id, company_id, trade_date,
    ROUND(open  * pre_adj_factor, 4)  AS open_adj,
    ROUND(high  * pre_adj_factor, 4)  AS high_adj,
    ROUND(low   * pre_adj_factor, 4)  AS low_adj,
    ROUND(close * pre_adj_factor, 4)  AS close_adj,
    volume, amount,
    change_pct, turnover_rate,
    limit_status, st_status, suspend_flag,
    pre_adj_factor, post_adj_factor, source_id
FROM daily_quotes;

COMMENT ON VIEW v_daily_quotes_adjusted IS
'前复权行情视图：open/high/low/close 均乘以 pre_adj_factor。
 复权因子存储在 daily_quotes 中每行，视图做乘法运算。
 业务层查询此视图即可获得真实可比的历史价格。';

-- ============================================================
-- 辅助函数：获取前N日（交易日）日期
-- ============================================================

CREATE OR REPLACE FUNCTION get_trading_days_before(
    p_company_id INT,
    p_base_date  DATE,
    p_days       INT
) RETURNS SETOF DATE
    LANGUAGE sql
    STABLE
AS $$
    SELECT trade_date
    FROM daily_quotes
    WHERE company_id = p_company_id
      AND trade_date <= p_base_date
      AND suspend_flag IS NOT TRUE
    ORDER BY trade_date DESC
    LIMIT p_days;
$$;
