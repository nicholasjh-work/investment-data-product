{{ config(materialized='table') }}

select
    account_key,
    security_key,
    as_of_date,
    quantity,
    price,
    market_value,
    cost_basis,
    unrealized_pnl,
    currency,
    _source_loaded_at
from {{ ref('int_position_enriched') }}
