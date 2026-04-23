{{ config(materialized='table') }}

select
    security_key,
    cusip,
    isin,
    ticker,
    source_issuer_key as issuer_key,
    sector,
    industry,
    listing_status,
    termination_date,
    effective_start_date,
    effective_end_date,
    is_current,
    _source_loaded_at
from {{ ref('int_security_versioned') }}
