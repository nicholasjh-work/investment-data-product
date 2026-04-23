-- Contract: no overlapping effective periods for the same CUSIP in dim_security.
with versions as (
    select
        cusip,
        effective_start_date,
        coalesce(effective_end_date, date '9999-12-31') as effective_end_date
    from {{ ref('dim_security') }}
)

select
    a.cusip,
    a.effective_start_date as a_start,
    a.effective_end_date   as a_end,
    b.effective_start_date as b_start,
    b.effective_end_date   as b_end
from versions a
join versions b
    on a.cusip = b.cusip
   and a.effective_start_date < b.effective_start_date
   and b.effective_start_date < a.effective_end_date
