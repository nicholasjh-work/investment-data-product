-- Contract: (account_key, security_key, as_of_date) is the position grain.
select
    account_key,
    security_key,
    as_of_date,
    count(*) as row_count
from {{ ref('fact_position') }}
group by account_key, security_key, as_of_date
having count(*) > 1
