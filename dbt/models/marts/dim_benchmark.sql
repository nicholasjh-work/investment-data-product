{{ config(materialized='table') }}

-- V1 publishes a single benchmark (S&P 500). Source carries only the key,
-- so the name is resolved here per the data contract.

with keys as (
    select distinct benchmark_key from {{ ref('stg_benchmark_constituent') }}
)

select
    benchmark_key,
    case benchmark_key
        when 1 then 'S&P 500'
        else 'Unknown'
    end as benchmark_name,
    'US' as country_of_domicile,
    'USD' as currency
from keys
