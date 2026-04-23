{{ config(materialized='view') }}

-- Transactions enriched with the regenerated security surrogate via CUSIP
-- lookup against the current security version.

with transactions as (
    select * from {{ ref('stg_transaction') }}
),

source_security as (
    select * from {{ ref('stg_security') }}
),

security as (
    select * from {{ ref('int_security_versioned') }}
    where is_current
),

tx_with_cusip as (
    select
        t.transaction_id,
        t.account_key,
        t.security_key as source_security_key,
        ss.cusip,
        t.trade_date,
        t.settle_date,
        t.transaction_type,
        t.quantity,
        t.price,
        t.gross_amount,
        t.net_amount,
        t.fees,
        t.commissions,
        t.currency,
        t._source_loaded_at
    from transactions t
    inner join source_security ss on ss.security_key = t.security_key
)

select
    tc.transaction_id,
    tc.account_key,
    s.security_key,
    tc.cusip,
    tc.trade_date,
    tc.settle_date,
    tc.transaction_type,
    tc.quantity,
    tc.price,
    tc.gross_amount,
    tc.net_amount,
    tc.fees,
    tc.commissions,
    tc.currency,
    tc._source_loaded_at
from tx_with_cusip tc
inner join security s on s.cusip = tc.cusip
