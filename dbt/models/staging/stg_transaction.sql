with source as (
    select * from {{ source('postgres_act', 'transaction') }}
)

select
    transaction_id,
    account_key,
    security_key,
    trade_date,
    settle_date,
    transaction_type,
    quantity,
    price,
    gross_amount,
    net_amount,
    fees,
    commissions,
    currency,
    source_system,
    source_updated_at as _source_loaded_at
from source
