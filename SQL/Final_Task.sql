--1. Выведите название самолетов, которые имеют менее 50 посадочных мест?
select a.model
from aircrafts a inner join seats s
on s.aircraft_code = a.aircraft_code 
group by a.aircraft_code
having count(seat_no) <50;


--2. Выведите процентное изменение ежемесячной суммы бронирования билетов, округленной до сотых.
select date_trunc('month', book_date ) as "month" ,  sum(total_amount), 
round(((sum(total_amount) - lag(sum(total_amount), 1) over (order by date_trunc('month', book_date))) / lag(sum(total_amount), 1) over (order by date_trunc('month', book_date))) * 100, 2) as "percentage_change"
from bookings
group by "month";

--2.1 Найти наилучший и наихудший месяц по бронированию билетов (количество и сумма)
with worst_month as(
					select date_trunc('month', book_date) as month, count(*) as booking_count,sum(total_amount) as total_revenue, 'worst' as category
					from bookings
					group by month
					order by booking_count,  total_revenue desc
					limit 1),
best_month as(
					select date_trunc('month', book_date) AS month, count(*) as booking_count,sum(total_amount) as total_revenue, 'best' as category
					from bookings
					group by month
					order by booking_count desc,  total_revenue 
					limit 1)
select *
from worst_month
union all
select*
from best_month



--3. Выведите названия самолетов не имеющих бизнес - класс. Решение должно быть через функцию array_agg.
select aircraft_code, array_agg(fare_conditions) as "class"
from seats 
group by aircraft_code
having not 'Business' =  any(array_agg(fare_conditions));


--4. Вывести накопительный итог количества мест в самолетах по каждому аэропорту на каждый день, учитывая только те самолеты, которые летали пустыми и только те дни, 
--где из одного аэропорта таких самолетов вылетало более одного.
--В результате должны быть код аэропорта, дата, количество пустых мест в самолете и накопительный итог.
with empty_flights as(
						select f.flight_id, f.flight_no, f.departure_airport,f.actual_departure, f.actual_departure::date as flight_date, count(s.seat_no) as "seats_amount"
						from flights f
						left join seats s
						on f.aircraft_code = s.aircraft_code
						where f.actual_departure is not null
						and not exists(
						select 1
						from boarding_passes bp
						where bp.flight_id = f.flight_id)
						group by f.flight_id,f.departure_airport,f.actual_departure),
	morethenone_flights as (
						select departure_airport, flight_date
						from empty_flights ef
						group by departure_airport, flight_date
						having count(flight_id) > 1)
select ef.departure_airport, ef.flight_date, ef.seats_amount, sum(ef.seats_amount) over(partition by ef.departure_airport, ef.flight_date  order by ef.actual_departure rows between unbounded preceding and current row) as "seats_cumulative_total"
from empty_flights ef
inner join morethenone_flights mf
on ef.departure_airport = mf.departure_airport
and ef.flight_date = mf.flight_date
order by ef.departure_airport, ef.flight_date,ef.actual_departure;


--5.Найдите процентное соотношение перелетов по маршрутам от общего количества перелетов.
--Выведите в результат названия аэропортов и процентное отношение.
--Решение должно быть через оконную функцию.
select distinct departure_airport_name, arrival_airport_name,round((count(flight_id) over (partition by departure_airport, arrival_airport)) * 100.0 / count(flight_id) over (), 2) AS "percentage"
from flights_v
order by percentage desc;


--6. Выведите количество пассажиров по каждому коду сотового оператора, если учесть, что код оператора - это три символа после +7
select substring(contact_data ->> 'phone' from 3 for 3) as "operator_code", count (passenger_id)
from tickets
group by "operator_code"
order by "operator_code";


--7. Классифицируйте финансовые обороты (сумма стоимости перелетов) по маршрутам:       
--До 50 млн - low
--От 50 млн включительно до 150 млн - middle
--От 150 млн включительно - high
select case
	when "total" < 50000000 then 'low'
	when "total" >= 50000000 and total < 150000000 then 'middle'
	else 'hight'
end as "classification", count(*) as "route_count"
from (
		select departure_airport,arrival_airport, sum(amount) as "total" 
		from flights f 
		inner join ticket_flights tf on f.flight_id = tf.flight_id 
		group by departure_airport,arrival_airport)
group by "classification";

--7.1 Найти маршрут с наибольшим финансовым оборотом
select departure_airport, arrival_airport, sum(amount) AS "total"
from ticket_flights tf
inner join flights f ON tf.flight_id = f.flight_id
group by f.departure_airport, f.arrival_airport
order by "total" DESC
limit 1;



--8. Вычислите медиану стоимости перелетов, медиану размера бронирования и отношение медианы бронирования к медиане стоимости перелетов, округленной до сотых
with flights_median as (
						select percentile_disc(0.5) within group (order by amount)::numeric as "flights_median1" -- Использовал дискретные фукции потому что в таблице целые без плавающих значений
						from ticket_flights	),  
	book_median 	as (
						select percentile_disc(0.5) within group (order by "total_amount")::numeric as "book_median1" -- Использовал дискретные фукции потому что в таблице целые без плавающих значений
						from bookings b )
select	fm.flights_median1, 	bm.book_median1, round(bm.book_median1/fm.flights_median1,2) as "ratio"
from flights_median fm cross join book_median bm;


-- 9.Найдите значение минимальной стоимости полета 1 км для пассажиров. То есть нужно найти расстояние между аэропортами и с учетом стоимости перелетов получить искомый результат		
select round(min(tf.amount / (earth_distance(ll_to_earth(dp.latitude, dp.longitude), ll_to_earth(ar.latitude, ar.longitude))::numeric / 1000)),2) AS "min_cost_per_km"
from bookings.flights bf
inner join ticket_flights tf on bf.flight_id = tf.flight_id
inner join airports dp on bf.departure_airport = dp.airport_code
inner join airports ar on bf.arrival_airport = ar.airport_code;
