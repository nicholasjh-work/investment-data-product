with source as (
    select * from {{ source('postgres_act', 'position') }}
)

select
    account_key,
    security_key,
    as_of_date,
    quantity,
    price,
    market_value,
    cost_basis,
    currency,
    source_system,
    source_updated_at as _source_loaded_at
from source
