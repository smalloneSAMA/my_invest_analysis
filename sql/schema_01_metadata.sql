-- ============================================================
-- Layer 1: 元数据层 - 数据源管理
-- 解决【坑2：多数据源冲突】的核心基础设施
-- ============================================================

-- 创建自定义枚举类型：数据类别
DO $$ BEGIN
    CREATE TYPE data_category_enum AS ENUM (
        'daily_quote',           -- 日行情
        'balance_sheet',         -- 资产负债表
        'income_statement',      -- 利润表
        'cash_flow_statement',   -- 现金流量表
        'share_capital',         -- 股本数据
        'dividend',              -- 分红记录
        'audit_opinion',         -- 审计意见
        'adjustment_event',      -- 除权除息事件
        'company_info'           -- 公司基本信息
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- 创建自定义枚举类型：报告期类型
DO $$ BEGIN
    CREATE TYPE report_type_enum AS ENUM (
        'annual',   -- 年报 (12-31)
        'q1',       -- 一季报 (03-31)
        'semi',     -- 半年报 (06-30)
        'q3'        -- 三季报 (09-30)
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- 创建自定义枚举类型：交易所
DO $$ BEGIN
    CREATE TYPE exchange_enum AS ENUM ('SH', 'SZ', 'BJ');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- 创建自定义枚举类型：上市板块
DO $$ BEGIN
    CREATE TYPE list_board_enum AS ENUM ('主板', '科创板', '创业板', '北交所');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- 创建自定义枚举类型：审计意见
DO $$ BEGIN
    CREATE TYPE audit_opinion_enum AS ENUM (
        '标准无保留意见',
        '带强调事项段的无保留意见',
        '保留意见',
        '否定意见',
        '无法表示意见'
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- 创建自定义枚举类型：除权事件类型
DO $$ BEGIN
    CREATE TYPE adj_event_type_enum AS ENUM (
        'dividend',        -- 现金分红
        'bonus_share',     -- 送股
        'transfer',        -- 转增
        'rights_issue',    -- 配股
        'split',           -- 拆细
        'reverse_split'    -- 合并
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ============================================================
-- 表1: data_sources - 数据源注册表
-- ============================================================
CREATE TABLE IF NOT EXISTS data_sources (
    id              SERIAL PRIMARY KEY,
    source_code     VARCHAR(20)  NOT NULL UNIQUE,
    source_name     VARCHAR(100) NOT NULL,
    description     TEXT,
    base_url        VARCHAR(500),
    is_active       BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE data_sources IS '数据源注册表：记录所有接入的数据源信息';
COMMENT ON COLUMN data_sources.source_code IS '数据源编码，如 mootdx / tencent / eastmoney / tushare';
COMMENT ON COLUMN data_sources.source_name IS '数据源名称，如 通达信mootdx / 腾讯行情 / 东方财富';
COMMENT ON COLUMN data_sources.is_active IS '是否启用，禁用后该源数据不再参与查询';

-- ============================================================
-- 表2: data_source_priority - 数据源优先级表
-- 解决【坑2】：按数据类别配置优先级，数字越小优先级越高
-- ============================================================
CREATE TABLE IF NOT EXISTS data_source_priority (
    id              SERIAL PRIMARY KEY,
    source_id       INT                NOT NULL REFERENCES data_sources(id) ON DELETE CASCADE,
    data_category   data_category_enum NOT NULL,
    priority        INT                NOT NULL DEFAULT 10,
    UNIQUE (source_id, data_category)
);

COMMENT ON TABLE data_source_priority IS '数据源优先级配置表：按数据类别设定各数据源的优先级，数字越小优先级越高';
COMMENT ON COLUMN data_source_priority.priority IS '优先级数值，1=最高优先(主源)，2=次选(备源)，3+=补充源。业务层按priority ASC取TOP1';
COMMENT ON COLUMN data_source_priority.data_category IS '数据类别，同一个源对不同类别可有不同优先级';

-- ============================================================
-- 预置默认数据源
-- ============================================================
INSERT INTO data_sources (source_code, source_name, description) VALUES
    ('mootdx',     '通达信mootdx', '通达信数据接口，免费稳定，推荐主源'),
    ('tencent',    '腾讯行情',     '腾讯财经行情接口，不封IP，推荐备源'),
    ('eastmoney',  '东方财富',     '东方财富数据接口，数据全面但需限流')
ON CONFLICT (source_code) DO NOTHING;

-- 默认优先级：mootdx=主源(1)，tencent=备源(2)，eastmoney=补充(3)
INSERT INTO data_source_priority (source_id, data_category, priority)
SELECT ds.id, cat.category::data_category_enum, cat.priority
FROM data_sources ds
CROSS JOIN (VALUES
    ('daily_quote',         1),
    ('balance_sheet',       1),
    ('income_statement',    1),
    ('cash_flow_statement', 1),
    ('share_capital',       1),
    ('dividend',            1),
    ('audit_opinion',       1),
    ('adjustment_event',    1),
    ('company_info',        1)
) AS cat(category, priority)
WHERE ds.source_code = 'mootdx'
ON CONFLICT (source_id, data_category) DO NOTHING;

INSERT INTO data_source_priority (source_id, data_category, priority)
SELECT ds.id, cat.category::data_category_enum, cat.priority
FROM data_sources ds
CROSS JOIN (VALUES
    ('daily_quote',         2),
    ('balance_sheet',       2),
    ('income_statement',    2),
    ('cash_flow_statement', 2),
    ('share_capital',       2),
    ('dividend',            2),
    ('audit_opinion',       2),
    ('adjustment_event',    2),
    ('company_info',        2)
) AS cat(category, priority)
WHERE ds.source_code = 'tencent'
ON CONFLICT (source_id, data_category) DO NOTHING;

INSERT INTO data_source_priority (source_id, data_category, priority)
SELECT ds.id, cat.category::data_category_enum, cat.priority
FROM data_sources ds
CROSS JOIN (VALUES
    ('daily_quote',         3),
    ('balance_sheet',       3),
    ('income_statement',    3),
    ('cash_flow_statement', 3),
    ('share_capital',       3),
    ('dividend',            3),
    ('audit_opinion',       3),
    ('adjustment_event',    3),
    ('company_info',        3)
) AS cat(category, priority)
WHERE ds.source_code = 'eastmoney'
ON CONFLICT (source_id, data_category) DO NOTHING;
