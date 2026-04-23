-- Contract: market_value must equal quantity * price within 1%.
select
    account_key,
    security_key,
    as_of_date,
    quantity,
    price,
    market_value,
    abs(market_value - quantity * price) / nullif(abs(market_value), 0) as drift_pct
from {{ ref('fact_position') }}
where market_value <> 0
  and abs(market_value - quantity * price) / nullif(abs(market_value), 0) > 0.01
