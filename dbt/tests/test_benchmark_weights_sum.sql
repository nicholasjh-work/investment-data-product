-- Contract: per benchmark per effective snapshot, sum(weight_pct) must be
-- within 100% +/- 0.1%.
select
    benchmark_key,
    effective_start_date,
    sum(weight_pct) as total_weight
from {{ ref('fact_benchmark_constituent') }}
group by benchmark_key, effective_start_date
having abs(sum(weight_pct) - 100) > 0.1
