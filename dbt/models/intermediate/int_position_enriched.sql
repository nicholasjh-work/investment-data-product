{{ config(materialized='view') }}

-- Positions enriched with the regenerated security surrogate via CUSIP
-- lookup against the current security version. Inner join drops positions
-- for any security not resolvable in the current dimension (survivorship
-- gate handles this separately).

with positions as (
    select * from {{ ref('stg_position') }}
),

-- The staging position table carries the source-side security_key; we need
-- the regenerated surrogate. Bridge through the source security table to
-- get CUSIP, then join to int_security_versioned on CUSIP.
source_security as (
    select * from {{ ref('stg_security') }}
),

security as (
    select * from {{ ref('int_security_versioned') }}
    where is_current
),

positions_with_cusip as (
    select
        p.account_key,
        p.security_key as source_security_key,
        ss.cusip,
        p.as_of_date,
        p.quantity,
        p.price,
        p.market_value,
        p.cost_basis,
        p.currency,
        p._source_loaded_at
    from positions p
    inner join source_security ss on ss.security_key = p.security_key
)

select
    pc.account_key,
    s.security_key,
    pc.cusip,
    pc.as_of_date,
    pc.quantity,
    pc.price,
    pc.market_value,
    pc.cost_basis,
    pc.market_value - pc.cost_basis as unrealized_pnl,
    pc.currency,
    pc._source_loaded_at
from positions_with_cusip pc
inner join security s on s.cusip = pc.cusip
