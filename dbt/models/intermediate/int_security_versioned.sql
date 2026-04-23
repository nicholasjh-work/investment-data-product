{{ config(materialized='view') }}

-- Effective-dated security master. Surrogate security_key is generated
-- via row_number() partitioned by natural key (CUSIP) and ordered by
-- effective start, so that Type 2 versions of the same security share
-- a stable surrogate across reloads. For v1 seed data every CUSIP has
-- one row, so is_current is true for all.

with src as (
    select * from {{ ref('stg_security') }}
),

versioned as (
    select
        row_number() over (order by cusip, _source_loaded_at) as security_key,
        cusip,
        isin,
        ticker,
        issuer_key as source_issuer_key,
        sector,
        industry,
        listing_status,
        termination_date,
        cast(_source_loaded_at as date) as effective_start_date,
        cast(null as date)              as effective_end_date,
        true                            as is_current,
        _source_loaded_at
    from src
)

select * from versioned
