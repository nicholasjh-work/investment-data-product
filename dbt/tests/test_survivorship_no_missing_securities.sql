-- Contract survivorship: every security_key referenced in fact_position or
-- fact_transaction must exist in dim_security.
with referenced as (
    select distinct security_key from {{ ref('fact_position') }}
    union
    select distinct security_key from {{ ref('fact_transaction') }}
),

known as (
    select distinct security_key from {{ ref('dim_security') }}
)

select r.security_key
from referenced r
left join known k on k.security_key = r.security_key
where k.security_key is null
