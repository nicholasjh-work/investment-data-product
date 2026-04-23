{{ config(materialized='table') }}

-- Benchmark constituents bridged to the regenerated security surrogate
-- via CUSIP. Inner join on the current security version per contract.

with bench as (
    select * from {{ ref('stg_benchmark_constituent') }}
),

source_security as (
    select * from {{ ref('stg_security') }}
),

security as (
    select * from {{ ref('int_security_versioned') }}
    where is_current
),

bench_with_cusip as (
    select
        b.benchmark_key,
        ss.cusip,
        b.effective_start_date,
        b.effective_end_date,
        b.weight_pct,
        b.shares_held,
        b._source_loaded_at
    from bench b
    inner join source_security ss on ss.security_key = b.security_key
)

select
    bc.benchmark_key,
    s.security_key,
    bc.effective_start_date,
    bc.effective_end_date,
    bc.weight_pct,
    bc.shares_held,
    bc._source_loaded_at
from bench_with_cusip bc
inner join security s on s.cusip = bc.cusip
