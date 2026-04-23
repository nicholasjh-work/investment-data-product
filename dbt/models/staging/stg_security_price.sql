with source as (
    select * from {{ source('azure_sql_ref', 'security_price') }}
)

select
    security_key,
    price_date,
    close_price,
    currency,
    source_system,
    source_updated_at as _source_loaded_at
from source
