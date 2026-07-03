-- =========================================================
-- DBMS CAPSTONE PROJECT
-- Grand Horizon Hotel Booking System
-- File: 02_queries.sql
-- =========================================================

-- This file contains:
-- 1. Ten parameterized queries using PostgreSQL PREPARE syntax.
-- 2. Two complex reports.
-- 3. One recursive CTE.
-- 4. One window function query.

-- Clear prepared statements in the current session if this file is re-run
DEALLOCATE ALL;

-- =========================================================
-- PART A: 10 PARAMETERIZED QUERIES
-- =========================================================

-- ---------------------------------------------------------
-- Query 1:
-- Retrieve a guest's profile by their email address.
-- Parameter:
-- $1 = guest email
-- ---------------------------------------------------------
PREPARE get_guest_by_email(VARCHAR) AS
SELECT
    guest_id,
    first_name,
    last_name,
    email,
    phone,
    date_of_birth,
    created_at
FROM guests
WHERE email = $1;

-- Test:
EXECUTE get_guest_by_email('aisha.alharbi@example.com');


-- ---------------------------------------------------------
-- Query 2:
-- Find all available rooms of a specific room_type between
-- a requested check_in and check_out date.
-- Parameters:
-- $1 = room type name
-- $2 = requested check-in date
-- $3 = requested check-out date
-- ---------------------------------------------------------
PREPARE find_available_rooms(VARCHAR, DATE, DATE) AS
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
WHERE rt.type_name = $1
  AND r.room_status = 'Available'
  AND NOT EXISTS (
      SELECT 1
      FROM bookings b
      WHERE b.room_id = r.room_id
        AND b.status IN ('Pending Payment', 'Confirmed')
        AND $2 < b.check_out
        AND $3 > b.check_in
  )
ORDER BY r.floor, r.room_number;

-- Test:
EXECUTE find_available_rooms('Standard', '2026-06-01', '2026-06-03');


-- ---------------------------------------------------------
-- Query 3:
-- List all active bookings for a specific guest_id.
-- Parameter:
-- $1 = guest_id
-- ---------------------------------------------------------
PREPARE active_bookings_for_guest(INT) AS
SELECT
    b.booking_id,
    b.guest_id,
    g.first_name,
    g.last_name,
    b.room_id,
    r.room_number,
    b.check_in,
    b.check_out,
    b.status,
    b.total_price
FROM bookings b
JOIN guests g
    ON b.guest_id = g.guest_id
JOIN rooms r
    ON b.room_id = r.room_id
WHERE b.guest_id = $1
  AND b.status IN ('Pending Payment', 'Confirmed')
  AND b.check_out > CURRENT_DATE
ORDER BY b.check_in;

-- Test:
EXECUTE active_bookings_for_guest(1);


-- ---------------------------------------------------------
-- Query 4:
-- Calculate the total revenue collected for a specific month and year.
-- Parameters:
-- $1 = month number
-- $2 = year number
-- ---------------------------------------------------------
PREPARE monthly_revenue(INT, INT) AS
SELECT
    EXTRACT(MONTH FROM payment_date) AS revenue_month,
    EXTRACT(YEAR FROM payment_date) AS revenue_year,
    SUM(amount - refund_amount) AS total_revenue_collected
FROM payments
WHERE payment_status IN ('Paid', 'Partially Refunded')
  AND EXTRACT(MONTH FROM payment_date) = $1
  AND EXTRACT(YEAR FROM payment_date) = $2
GROUP BY
    EXTRACT(MONTH FROM payment_date),
    EXTRACT(YEAR FROM payment_date);

-- Test:
EXECUTE monthly_revenue(5, 2026);


-- ---------------------------------------------------------
-- Query 5:
-- List all bookings that have a status of 'Pending Payment'.
-- No user parameter needed because the required status is fixed.
-- ---------------------------------------------------------
PREPARE pending_payment_bookings AS
SELECT
    b.booking_id,
    g.first_name,
    g.last_name,
    g.email,
    r.room_number,
    b.check_in,
    b.check_out,
    b.total_price,
    b.status
FROM bookings b
JOIN guests g
    ON b.guest_id = g.guest_id
JOIN rooms r
    ON b.room_id = r.room_id
WHERE b.status = 'Pending Payment'
ORDER BY b.check_in;

-- Test:
EXECUTE pending_payment_bookings;


-- ---------------------------------------------------------
-- Query 6:
-- Find all rooms located on a specific floor.
-- Parameter:
-- $1 = floor number
-- ---------------------------------------------------------
PREPARE rooms_by_floor(INT) AS
SELECT
    r.room_id,
    r.room_number,
    r.floor,
    rt.type_name,
    rt.capacity,
    r.room_status
FROM rooms r
JOIN room_types rt
    ON r.room_type_id = rt.room_type_id
WHERE r.floor = $1
ORDER BY r.room_number;

-- Test:
EXECUTE rooms_by_floor(3);


-- ---------------------------------------------------------
-- Query 7:
-- Retrieve all canceled bookings that occurred within the last X days.
-- Parameter:
-- $1 = number of days
-- ---------------------------------------------------------
PREPARE canceled_bookings_last_x_days(INT) AS
SELECT
    b.booking_id,
    g.first_name,
    g.last_name,
    r.room_number,
    b.check_in,
    b.check_out,
    b.total_price,
    b.canceled_at
FROM bookings b
JOIN guests g
    ON b.guest_id = g.guest_id
JOIN rooms r
    ON b.room_id = r.room_id
WHERE b.status = 'Canceled'
  AND b.canceled_at >= CURRENT_TIMESTAMP - ($1 * INTERVAL '1 day')
ORDER BY b.canceled_at DESC;

-- Test:
EXECUTE canceled_bookings_last_x_days(365);


-- ---------------------------------------------------------
-- Query 8:
-- Find all employees hired after a specific date.
-- Parameter:
-- $1 = hire date
-- ---------------------------------------------------------
PREPARE employees_hired_after(DATE) AS
SELECT
    employee_id,
    first_name,
    last_name,
    role,
    manager_id,
    hire_date
FROM employees
WHERE hire_date > $1
ORDER BY hire_date;

-- Test:
EXECUTE employees_hired_after('2022-01-01');


-- ---------------------------------------------------------
-- Query 9:
-- Calculate the total amount of refunds issued for a given date range.
-- Parameters:
-- $1 = start timestamp
-- $2 = end timestamp
-- ---------------------------------------------------------
PREPARE refunds_by_date_range(TIMESTAMP, TIMESTAMP) AS
SELECT
    SUM(refund_amount) AS total_refunds_issued
FROM payments
WHERE refund_amount > 0
  AND payment_date BETWEEN $1 AND $2;

-- Test:
EXECUTE refunds_by_date_range('2026-01-01 00:00:00', '2026-12-31 23:59:59');


-- ---------------------------------------------------------
-- Query 10:
-- Find the current room rate for a specific room_id.
-- Parameter:
-- $1 = room_id
-- ---------------------------------------------------------
PREPARE current_room_rate(INT) AS
SELECT
    r.room_id,
    r.room_number,
    rt.type_name,
    rt.base_price AS current_rate_per_night
FROM rooms r
JOIN room_types rt
    ON r.room_type_id = rt.room_type_id
WHERE r.room_id = $1;

-- Test:
EXECUTE current_room_rate(8);


-- =========================================================
-- PART B: COMPLEX REPORTS
-- =========================================================

-- ---------------------------------------------------------
-- Report 1:
-- Revenue by Room Type
-- Requirements:
-- - At least 3 JOINs: rooms, room_types, bookings, payments
-- - Aggregate total revenue
-- - GROUP BY room type
-- - HAVING total revenue > 5000
-- ---------------------------------------------------------
SELECT
    rt.type_name,
    COUNT(b.booking_id) AS total_bookings,
    SUM(p.amount - p.refund_amount) AS total_revenue
FROM room_types rt
JOIN rooms r
    ON rt.room_type_id = r.room_type_id
JOIN bookings b
    ON r.room_id = b.room_id
JOIN payments p
    ON b.booking_id = p.booking_id
WHERE p.payment_status IN ('Paid', 'Partially Refunded')
GROUP BY rt.type_name
HAVING SUM(p.amount - p.refund_amount) > 5000
ORDER BY total_revenue DESC;


-- ---------------------------------------------------------
-- Report 2:
-- Frequent Cancellers
-- Identify guests who canceled more than 2 bookings in the past year.
-- Uses a CTE to isolate the timeframe.
-- ---------------------------------------------------------
WITH canceled_last_year AS (
    SELECT
        b.booking_id,
        b.guest_id,
        b.canceled_at
    FROM bookings b
    WHERE b.status = 'Canceled'
      AND b.canceled_at >= CURRENT_DATE - INTERVAL '1 year'
)
SELECT
    g.guest_id,
    g.first_name,
    g.last_name,
    g.email,
    COUNT(c.booking_id) AS cancellation_count
FROM canceled_last_year c
JOIN guests g
    ON c.guest_id = g.guest_id
GROUP BY
    g.guest_id,
    g.first_name,
    g.last_name,
    g.email
HAVING COUNT(c.booking_id) > 2
ORDER BY cancellation_count DESC;


-- =========================================================
-- PART C: RECURSIVE CTE
-- =========================================================

-- ---------------------------------------------------------
-- Recursive CTE:
-- Given an employee_id, return their entire management chain
-- up to the General Manager.
--
-- Change the employee_id in the first WHERE condition to test
-- another employee.
-- Example below starts from employee_id = 8.
-- ---------------------------------------------------------
WITH RECURSIVE management_chain AS (
    SELECT
        employee_id,
        first_name,
        last_name,
        role,
        manager_id,
        1 AS hierarchy_level
    FROM employees
    WHERE employee_id = 8

    UNION ALL

    SELECT
        e.employee_id,
        e.first_name,
        e.last_name,
        e.role,
        e.manager_id,
        mc.hierarchy_level + 1
    FROM employees e
    JOIN management_chain mc
        ON e.employee_id = mc.manager_id
)
SELECT
    hierarchy_level,
    employee_id,
    first_name,
    last_name,
    role,
    manager_id
FROM management_chain
ORDER BY hierarchy_level;


-- =========================================================
-- PART D: WINDOW FUNCTION QUERY
-- =========================================================

-- ---------------------------------------------------------
-- Rank guests by lifetime total spending at the hotel.
-- Uses DENSE_RANK() OVER (...)
-- ---------------------------------------------------------
SELECT
    g.guest_id,
    g.first_name,
    g.last_name,
    g.email,
    COALESCE(SUM(p.amount - p.refund_amount), 0) AS lifetime_spending,
    DENSE_RANK() OVER (
        ORDER BY COALESCE(SUM(p.amount - p.refund_amount), 0) DESC
    ) AS spending_rank
FROM guests g
LEFT JOIN bookings b
    ON g.guest_id = b.guest_id
LEFT JOIN payments p
    ON b.booking_id = p.booking_id
GROUP BY
    g.guest_id,
    g.first_name,
    g.last_name,
    g.email
ORDER BY spending_rank;