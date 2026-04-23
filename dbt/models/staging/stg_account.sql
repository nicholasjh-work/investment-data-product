with source as (
    select * from {{ source('postgres_act', 'account') }}
)

select
    account_key,
    account_number,
    account_name,
    account_type,
    base_currency,
    opened_date,
    closed_date,
    source_system,
    source_updated_at as _source_loaded_at
from source
