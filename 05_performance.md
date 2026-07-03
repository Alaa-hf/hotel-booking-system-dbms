# Phase 5: Performance Optimization

## Query Selected

The query selected for optimization is the "Check Available Rooms" query from Phase 2.  
This query finds rooms of a specific room type that are available between a requested check-in and check-out date.

The query checks room availability by searching the bookings table and excluding rooms that have active overlapping bookings.

## Query Before Index

sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT
r.room_id,
r.room_number,
r.floor,
rt.type_name,
rt.base_price,
rt.capacity
FROM rooms r
JOIN room_types rt
ON r.room_type_id = rt.room_type_id
WHERE rt.type_name = 'Standard'
AND r.room_status = 'Available'
AND NOT EXISTS (
SELECT 1
FROM bookings b
WHERE b.room_id = r.room_id
AND b.status IN ('Pending Payment', 'Confirmed')
AND DATE '2026-06-01' < b.check_out
AND DATE '2026-06-03' > b.check_in
)
ORDER BY r.floor, r.room_number;

## EXPLAIN ANALYZE Output Before Index

text
-> Bitmap Heap Scan on bookings b (cost=2.84..9.97 rows=1 width=4) (actual time=0.005..0.005 rows=0.12 loops=8)
Recheck Cond: (room_id = r.room_id)
Filter: (((status)::text = ANY ('{"Pending Payment",Confirmed}'::text[])) AND ('2026-06-01'::date < check_out) AND ('2026-06-03'::date > check_in))
Rows Removed by Filter: 1
Heap Blocks: exact=8
Buffers: shared hit=16 dirtied=1
-> Bitmap Index Scan on idx_bookings_room_id (cost=0.00..2.84 rows=3 width=0) (actual time=0.001..0.001 rows=1.50 loops=8)
Index Cond: (room_id = r.room_id)
Index Searches: 8
Buffers: shared hit=8
Planning:
Buffers: shared hit=218
Planning Time: 2.324 ms
Execution Time: 0.159 ms

## Index Added

To improve the availability-check query, the following composite index was added:

sql
CREATE INDEX IF NOT EXISTS idx_bookings_room_dates
ON bookings(room_id, check_in, check_out);

This index supports the query because the availability check searches the bookings table using room_id, check_in, and check_out.

## Query After Index

The same availability query was executed again after adding the composite index.

sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT
r.room_id,
r.room_number,
r.floor,
rt.type_name,
rt.base_price,
rt.capacity
FROM rooms r
JOIN room_types rt
ON r.room_type_id = rt.room_type_id
WHERE rt.type_name = 'Standard'
AND r.room_status = 'Available'
AND NOT EXISTS (
SELECT 1
FROM bookings b
WHERE b.room_id = r.room_id
AND b.status IN ('Pending Payment', 'Confirmed')
AND DATE '2026-06-01' < b.check_out
AND DATE '2026-06-03' > b.check_in
)
ORDER BY r.floor, r.room_number;

## EXPLAIN ANALYZE Output After Index

text
QUERY PLAN
Join Filter: (b.room_id = r.room_id)
Rows Removed by Join Filter: 7
Buffers: shared hit=11
-> Nested Loop (cost=0.15..25.70 rows=1 width=184) (actual time=0.023..0.028 rows=8.00 loops=1)
Join Filter: (rt.room_type_id = r.room_type_id)
Rows Removed by Join Filter: 20
Buffers: shared hit=3
-> Index Scan using room_types_type_name_key on room_types rt (cost=0.15..8.17 rows=1 width=142) (actual time=0.012..0.012 rows=1.00 loops=1)
Index Cond: ((type_name)::text = 'Standard'::text)
Index Searches: 1
Buffers: shared hit=2
-> Seq Scan on rooms r (cost=0.00..17.50 rows=3 width=50) (actual time=0.010..0.013 rows=28.00 loops=1)
Filter: ((room_status)::text = 'Available'::text)
Rows Removed by Filter: 2
Buffers: shared hit=1
-> Seq Scan on bookings b (cost=0.00..1.72 rows=1 width=4) (actual time=0.003..0.005 rows=1.00 loops=8)
Filter: (((status)::text = ANY ('{"Pending Payment",Confirmed}'::text[])) AND ('2026-06-01'::date < check_out) AND ('2026-06-03'::date > check_in))
Rows Removed by Filter: 37
Buffers: shared hit=8
Planning:
Buffers: shared hit=246 read=1
Planning Time: 2.633 ms
Execution Time: 0.147 ms

## Performance Comparison

Before index execution time: 0.159 ms  
After index execution time: 0.147 ms

The execution time decreased by 0.012 ms, which is a small improvement of approximately 7.5%.

## Discussion

The selected query checks room availability by looking for active bookings that overlap with the requested check-in and check-out dates.

A composite index was added on bookings(room_id, check_in, check_out) because these columns are used in the overlap-checking condition.

Before adding the composite index, PostgreSQL used the existing idx_bookings_room_id index to search bookings by room ID. After adding the composite index, PostgreSQL still chose a sequential scan on the bookings table. This is acceptable in this project because the sample dataset is very small, so PostgreSQL may estimate that scanning the small table is cheaper than using the new composite index.

The execution time changed from 0.159 ms to 0.147 ms, showing a small improvement. In a real hotel booking system with thousands or millions of booking records, the composite index would be more useful because it would help PostgreSQL locate relevant bookings faster when checking room availability.
