{{ config(materialized='table') }}

select
    issuer_key,
    lei,
    issuer_name,
    parent_lei,
    parent_issuer_key,
    country_of_domicile,
    effective_start_date,
    effective_end_date,
    is_current,
    _source_loaded_at
from {{ ref('int_issuer_hierarchy') }}
