{{ config(materialized='table') }}

with calendar as (
    select cast(d as date) as date_day
    from generate_series('2024-04-01'::date, '2025-04-30'::date, interval '1 day') as d
)

select
    date_day                                        as date_key,
    date_day,
    extract(year  from date_day)::int               as year,
    extract(month from date_day)::int               as month,
    extract(day   from date_day)::int               as day_of_month,
    extract(isodow from date_day)::int              as day_of_week,
    to_char(date_day, 'Day')                        as day_name,
    case when extract(isodow from date_day) in (6, 7) then false else true end as is_trading_day,
    case
        when extract(month from date_day) in (1, 2, 3)   then 1
        when extract(month from date_day) in (4, 5, 6)   then 2
        when extract(month from date_day) in (7, 8, 9)   then 3
        else 4
    end                                             as fiscal_quarter
from calendar
