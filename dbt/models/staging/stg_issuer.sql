with source as (
    select * from {{ source('azure_sql_ref', 'dim_issuer') }}
)

select
    issuer_key,
    lei,
    issuer_name,
    parent_issuer_key,
    country_of_domicile,
    effective_start_date,
    effective_end_date,
    source_system,
    source_updated_at as _source_loaded_at
from source
