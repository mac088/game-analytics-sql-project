/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 * 
 * Автор: Немич Максим Сергеевич
 * Дата: 15.10.2025
*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков

-- 1.1. Доля платящих пользователей по всем данным:
-- Напишите ваш запрос здесь
select 
    count(id) as count_users,
    sum(case when payer = 1 then 1 else 0 end) as pay_users,
    round(avg((payer = 1)::int)::numeric, 4) as avg_pay_users
from fantasy.users;
-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
-- Напишите ваш запрос здесь
select 
    r.race as race,
    count(u.id) as total_race_users,
    sum(case when u.payer = 1 then 1 else 0 end) as pay_race_users,
    round(avg((u.payer = 1)::int)::numeric, 4) as payer_to_total
from fantasy.users u
left join fantasy.race r on u.race_id = r.race_id
group by r.race
order by payer_to_total desc;


-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:
-- Напишите ваш запрос здесь
select 
		count(*),
		sum(amount),
		min(amount),
		max(amount),
		avg(amount),
		PERCENTILE_CONT(0.5) within group (order by amount) as median_amount,
		STDDEV(amount) as stand_dev
from fantasy.events
-- 2.2: Аномальные нулевые покупки:
-- Напишите ваш запрос здесь
select 
    (select count(*) from fantasy.events where amount = 0) as zero_count,
    (select count(*) from fantasy.events where amount = 0) * 100.0 / count(*) AS amount_percent
from fantasy.events;
-- 2.3: Популярные эпические предметы:
-- Напишите ваш запрос здесь
with total as (
    select
        count(*) as total_orders,
        count(distinct id) as total_buyers,
        sum(amount) as total_revenue
    from fantasy.events
    where amount > 0
)
select
    es.item_code as product_key,
    coalesce(i.game_items, es.item_code::text) as product_name,
    count(*) as orders_count,  -- абсолютное число продаж
    round((count(*)::numeric / nullif(t.total_orders, 0))::numeric, 4) as orders_share,  -- доля продаж от всех продаж
    count(distinct es.id) as buyers_count,  -- число уникальных игроков, купивших предмет
    round((count(distinct es.id)::numeric / nullif(t.total_buyers, 0))::numeric, 4) as buyers_share, -- доля этих игроков от всех покупателей
    round(sum(es.amount)::numeric, 2) as total_revenue  -- суммарный доход по предмету
from fantasy.events es
left join fantasy.items i on i.item_code = es.item_code
cross join total t
where es.amount > 0
group by es.item_code, i.game_items, t.total_orders, t.total_buyers
order by buyers_share desc, buyers_count desc, orders_count desc;



-- Часть 2. Решение ad hoc-задачbи
-- Задача: Зависимость активности игроков от расы персонажа:
-- Напишите ваш запрос здесь

with per_player as (
    select
        u.id as user_id,
        u.race_id,
        max(case when u.payer = 1 then 1 else 0 end) as is_payer,
        count(e.transaction_id) filter (where e.amount > 0) as total_orders,
        sum(e.amount) filter (where e.amount > 0) as total_spent
    from fantasy.users u
    left join fantasy.events e on e.id = u.id
    group by u.id, u.race_id
),
race_agg as (
    select
        r.race_id,
        r.race as race_name,
        count(p.user_id) as total_registered,
        count(p.user_id) filter (where p.total_orders > 0) as buyers_count,
        round((count(p.user_id) filter (where p.total_orders > 0))::numeric / nullif(count(p.user_id),0), 4) as buyers_share,
        count(p.user_id) filter (where p.total_orders > 0 and p.is_payer = 1) as buyers_who_are_payers,
        round((count(p.user_id) filter (where p.total_orders > 0 and p.is_payer = 1))::numeric / nullif(count(p.user_id) filter (where p.total_orders > 0),0), 4) as share_payers_among_buyers,
        sum(p.total_orders) filter (where p.total_orders > 0) as total_orders_by_buyers,
        sum(p.total_spent) filter (where p.total_orders > 0) as total_spent_by_buyers
    from fantasy.race r
    left join per_player p on p.race_id = r.race_id
    group by r.race_id, r.race
)
select
    race_id,
    race_name,
    total_registered,
    buyers_count,
    buyers_share,
    buyers_who_are_payers,
    share_payers_among_buyers,
    total_orders_by_buyers,
    round(total_spent_by_buyers::numeric / nullif(total_orders_by_buyers,0), 2) as avg_amount_per_order,
    round(total_spent_by_buyers::numeric / nullif(buyers_count,0), 2) as avg_total_spent_per_buyer,
    round(total_orders_by_buyers::numeric / nullif(buyers_count,0), 4) as avg_orders_per_buyer
from race_agg
order by share_payers_among_buyers desc nulls last;





