{{ config(materialized='incremental', unique_key='run_id') }}

-- Run log for the investment data product. Seeded empty via `where false`;
-- subsequent runs append rows produced by orchestration / quality gates.

select
    cast(null as varchar(64))   as run_id,
    cast(null as timestamp)     as run_timestamp,
    cast(null as varchar(128))  as dataset,
    cast(null as bigint)        as source_row_count,
    cast(null as bigint)        as curated_row_count,
    cast(null as numeric(10,6)) as drift_pct,
    cast(null as varchar(16))   as sla_status,
    cast(null as boolean)       as checks_passed,
    cast(null as text)          as failure_message
where false
