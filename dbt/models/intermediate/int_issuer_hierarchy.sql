{{ config(materialized='view') }}

-- Effective-dated issuer master with resolved parent hierarchy. Surrogate
-- issuer_key is regenerated via row_number() over the natural key (LEI).
-- Parent resolution: source carries parent_issuer_key (source-side key),
-- which we map to parent LEI and then to the regenerated surrogate.

with src as (
    select * from {{ ref('stg_issuer') }}
),

keyed as (
    select
        row_number() over (order by lei, _source_loaded_at) as issuer_key,
        lei,
        issuer_name,
        parent_issuer_key as source_parent_issuer_key,
        country_of_domicile,
        cast(_source_loaded_at as date) as effective_start_date,
        cast(null as date)              as effective_end_date,
        true                            as is_current,
        _source_loaded_at
    from src
),

parent_map as (
    -- map source-side parent key -> parent LEI -> regenerated surrogate
    select
        child.issuer_key,
        parent_src.lei           as parent_lei,
        parent_keyed.issuer_key  as parent_issuer_key
    from keyed child
    left join src       parent_src   on parent_src.issuer_key = child.source_parent_issuer_key
    left join keyed     parent_keyed on parent_keyed.lei       = parent_src.lei
)

select
    k.issuer_key,
    k.lei,
    k.issuer_name,
    pm.parent_lei,
    pm.parent_issuer_key,
    k.country_of_domicile,
    k.effective_start_date,
    k.effective_end_date,
    k.is_current,
    k._source_loaded_at
from keyed k
left join parent_map pm on pm.issuer_key = k.issuer_key
