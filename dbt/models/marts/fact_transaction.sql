{{ config(materialized='table') }}

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
    _source_loaded_at
from {{ ref('int_transaction_enriched') }}
