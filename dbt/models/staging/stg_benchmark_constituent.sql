with source as (
    select * from {{ source('azure_sql_ref', 'benchmark_constituent') }}
)

select
    benchmark_key,
    security_key,
    effective_start_date,
    effective_end_date,
    weight_pct,
    shares_held,
    source_system,
    source_updated_at as _source_loaded_at
from source
