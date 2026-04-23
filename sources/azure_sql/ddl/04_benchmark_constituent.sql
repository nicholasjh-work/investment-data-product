-- Benchmark membership with Type 2 effective dating.
-- V1: single benchmark (S&P 500 = benchmark_key 1).
DROP TABLE IF EXISTS investments_ref.benchmark_constituent CASCADE;

CREATE TABLE investments_ref.benchmark_constituent (
    benchmark_key         BIGINT        NOT NULL,
    security_key          BIGINT        NOT NULL,
    effective_start_date  DATE          NOT NULL,
    effective_end_date    DATE          NULL,
    weight_pct            NUMERIC(10,6) NOT NULL,
    shares_held           NUMERIC(20,4) NULL,
    source_system         VARCHAR(50)   NOT NULL DEFAULT 'AZURE_SQL_REF',
    source_updated_at     TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (benchmark_key, security_key, effective_start_date)
);

CREATE INDEX ix_bench_sec ON investments_ref.benchmark_constituent (security_key);
CREATE INDEX ix_bench_active ON investments_ref.benchmark_constituent (benchmark_key, security_key) WHERE effective_end_date IS NULL;
