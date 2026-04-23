-- Contract: every non-null parent_issuer_key must resolve to an issuer row.
select
    child.issuer_key,
    child.lei,
    child.parent_issuer_key
from {{ ref('dim_issuer') }} child
left join {{ ref('dim_issuer') }} parent
    on parent.issuer_key = child.parent_issuer_key
where child.parent_issuer_key is not null
  and parent.issuer_key is null
