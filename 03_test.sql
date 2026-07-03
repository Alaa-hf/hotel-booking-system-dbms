-- =========================================================
-- DBMS CAPSTONE PROJECT
-- Grand Horizon Hotel Booking System
-- File: 03_test.sql
-- =========================================================

-- This file demonstrates:
-- 1. Successful booking through the book_room procedure.
-- 2. Failed booking due to overlapping dates.
-- 3. Failed booking because guest already has 3 active bookings.
-- 4. Overlap prevention trigger.
-- 5. Audit log trigger after manual booking status update.
-- 6. Refund function for early and late cancellations.

-- =========================================================
-- CLEAN PREVIOUS TEST DATA IF THIS FILE IS RE-RUN
-- =========================================================

DELETE FROM bookings
WHERE check_in >= '2027-01-01';

DELETE FROM audit_log;

-- =========================================================
-- TEST 1: SUCCESSFUL BOOKING THROUGH PROCEDURE
-- =========================================================

-- Guest 19 books room 2 for non-overlapping future dates.
CALL book_room(
    19,
    2,
    '2027-02-01',
    '2027-02-04',
    NULL,
    NULL
);

-- Show the newly created booking.
SELECT
    booking_id,
    guest_id,
    room_id,
    check_in,
    check_out,
    status,
    locked_rate_per_night,
    total_price
FROM bookings
WHERE check_in = '2027-02-01'
  AND check_out = '2027-02-04'
  AND guest_id = 19
  AND room_id = 2;


-- =========================================================
-- TEST 2: FAILED BOOKING DUE TO OVERLAP THROUGH PROCEDURE
-- =========================================================

-- Room 1 is already booked from 2026-06-01 to 2026-06-03.
-- This requested date range overlaps, so the procedure should fail.
CALL book_room(
    3,
    1,
    '2026-06-02',
    '2026-06-04',
    NULL,
    NULL
);


-- =========================================================
-- TEST 3: FAILED BOOKING BECAUSE GUEST ALREADY HAS 3 ACTIVE BOOKINGS
-- =========================================================

-- Guest 1 already has 3 active future bookings in the sample data.
CALL book_room(
    1,
    6,
    '2027-03-01',
    '2027-03-05',
    NULL,
    NULL
);


-- =========================================================
-- TEST 4: DIRECT TRIGGER TEST FOR OVERLAP PREVENTION
-- =========================================================

-- This direct insert should fail because it overlaps with room 1 booking.
-- The DO block catches the error so the script can continue running.

DO $$
BEGIN
    INSERT INTO bookings (
        guest_id,
        room_id,
        check_in,
        check_out,
        status,
        locked_rate_per_night,
        total_price
    )
    VALUES (
        4,
        1,
        '2026-06-02',
        '2026-06-04',
        'Confirmed',
        120.00,
        240.00
    );

EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Expected overlap error caught: %', SQLERRM;
END;
$$;


-- =========================================================
-- TEST 5: AUDIT LOG TRIGGER
-- =========================================================

-- Manually update the successful test booking from Pending Payment to Canceled.
-- This should insert one row into audit_log.

UPDATE bookings
SET
    status = 'Canceled',
    canceled_at = CURRENT_TIMESTAMP
WHERE check_in = '2027-02-01'
  AND check_out = '2027-02-04'
  AND guest_id = 19
  AND room_id = 2;

-- Show audit log result.
SELECT
    log_id,
    table_name,
    operation,
    old_status,
    new_status,
    changed_by,
    change_timestamp
FROM audit_log
ORDER BY log_id;


-- =========================================================
-- TEST 6: REFUND FUNCTION
-- =========================================================

-- Late cancellation example:
-- Booking 11 check-in is 2026-01-10.
-- Cancellation on 2026-01-09 is fewer than 48 hours before check-in.
-- Expected refund = 50% of total price.

SELECT
    booking_id,
    total_price,
    calculate_refund(11, '2026-01-09 18:00:00') AS late_cancellation_refund
FROM bookings
WHERE booking_id = 11;


-- Early cancellation example:
-- Booking 12 check-in is 2026-03-12.
-- Cancellation on 2026-03-01 is earlier than 48 hours before check-in.
-- Expected refund = 100% of total price.

SELECT
    booking_id,
    total_price,
    calculate_refund(12, '2026-03-01 12:00:00') AS early_cancellation_refund
FROM bookings
WHERE booking_id = 12;


-- =========================================================
-- FINAL CHECK: CURRENT BOOKING STATUS COUNTS
-- =========================================================

SELECT
    status,
    COUNT(*) AS total_bookings
FROM bookings
GROUP BY status
ORDER BY status;