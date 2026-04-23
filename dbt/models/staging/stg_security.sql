with source as (
    select * from {{ source('azure_sql_ref', 'dim_security') }}
)

select
    security_key,
    cusip,
    isin,
    ticker,
    issuer_key,
    sector,
    industry,
    listing_status,
    termination_date,
    effective_start_date,
    effective_end_date,
    source_system,
    source_updated_at as _source_loaded_at
from source
