-- =========================================================
-- DBMS CAPSTONE PROJECT
-- Grand Horizon Hotel Booking System
-- File: 03_procedures_triggers.sql
-- =========================================================

-- This file contains:
-- 1. calculate_refund() stored function
-- 2. book_room() stored procedure
-- 3. overlap prevention trigger
-- 4. audit logging trigger

-- =========================================================
-- CLEAN OLD OBJECTS IF RE-RUNNING THIS FILE
-- =========================================================

DROP TRIGGER IF EXISTS trg_prevent_booking_overlap ON bookings;
DROP FUNCTION IF EXISTS prevent_booking_overlap();

DROP TRIGGER IF EXISTS trg_audit_booking_status_change ON bookings;
DROP FUNCTION IF EXISTS audit_booking_status_change();

DROP PROCEDURE IF EXISTS book_room(INT, INT, DATE, DATE);
DROP FUNCTION IF EXISTS calculate_refund(INT, TIMESTAMP);


-- =========================================================
-- STEP 3.1: STORED FUNCTION calculate_refund
-- =========================================================
-- Rule:
-- If cancellation happens fewer than 48 hours before check-in,
-- refund = 50% of total booking price.
-- Otherwise, refund = 100% of total booking price.
-- =========================================================

CREATE OR REPLACE FUNCTION calculate_refund(
    p_booking_id INT,
    p_cancel_date TIMESTAMP
)
RETURNS DECIMAL(10,2)
LANGUAGE plpgsql
AS $$
DECLARE
    v_check_in DATE;
    v_total_price DECIMAL(10,2);
    v_refund_amount DECIMAL(10,2);
BEGIN
    SELECT
        check_in,
        total_price
    INTO
        v_check_in,
        v_total_price
    FROM bookings
    WHERE booking_id = p_booking_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Booking ID % does not exist.', p_booking_id;
    END IF;

    IF p_cancel_date >= (v_check_in::TIMESTAMP - INTERVAL '48 hours') THEN
        v_refund_amount := v_total_price * 0.50;
    ELSE
        v_refund_amount := v_total_price;
    END IF;

    RETURN v_refund_amount;
END;
$$;


-- =========================================================
-- STEP 3.2: STORED PROCEDURE book_room
-- Includes explicit COMMIT and ROLLBACK transaction control
-- =========================================================

DROP PROCEDURE IF EXISTS book_room(INT, INT, DATE, DATE);

CREATE OR REPLACE PROCEDURE book_room(
    IN p_guest_id INT,
    IN p_room_id INT,
    IN p_check_in DATE,
    IN p_check_out DATE,
    OUT p_success BOOLEAN,
    OUT p_message VARCHAR
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_guest_exists BOOLEAN;
    v_room_exists BOOLEAN;
    v_active_booking_count INT;
    v_overlap_exists BOOLEAN;
    v_rate_per_night DECIMAL(10,2);
    v_total_nights INT;
    v_total_price DECIMAL(10,2);
    v_new_booking_id INT;
BEGIN
    p_success := FALSE;
    p_message := 'Booking was not completed.';

    -- 1. Validate dates
    IF p_check_out <= p_check_in THEN
        p_message := 'Error: Check-out date must be after check-in date.';
        ROLLBACK;
        RETURN;
    END IF;

    -- 2. Check guest exists
    SELECT EXISTS (
        SELECT 1
        FROM guests
        WHERE guest_id = p_guest_id
    )
    INTO v_guest_exists;

    IF v_guest_exists = FALSE THEN
        p_message := 'Error: Guest does not exist.';
        ROLLBACK;
        RETURN;
    END IF;

    -- 3. Check room exists and is available
    SELECT EXISTS (
        SELECT 1
        FROM rooms
        WHERE room_id = p_room_id
          AND room_status = 'Available'
    )
    INTO v_room_exists;

    IF v_room_exists = FALSE THEN
        p_message := 'Error: Room does not exist or is not available.';
        ROLLBACK;
        RETURN;
    END IF;

    -- 4. Check guest active future booking limit
    SELECT COUNT(*)
    INTO v_active_booking_count
    FROM bookings
    WHERE guest_id = p_guest_id
      AND status IN ('Pending Payment', 'Confirmed')
      AND check_out > CURRENT_DATE;

    IF v_active_booking_count >= 3 THEN
        p_message := 'Error: Guest already has 3 active future bookings.';
        ROLLBACK;
        RETURN;
    END IF;

    -- 5. Check room overlap
    SELECT EXISTS (
        SELECT 1
        FROM bookings
        WHERE room_id = p_room_id
          AND status IN ('Pending Payment', 'Confirmed')
          AND p_check_in < check_out
          AND p_check_out > check_in
    )
    INTO v_overlap_exists;

    IF v_overlap_exists = TRUE THEN
        p_message := 'Error: Room is already booked for the selected dates.';
        ROLLBACK;
        RETURN;
    END IF;

    -- 6. Get current room rate
    SELECT rt.base_price
    INTO v_rate_per_night
    FROM rooms r
    JOIN room_types rt
        ON r.room_type_id = rt.room_type_id
    WHERE r.room_id = p_room_id;

    -- 7. Calculate total price
    v_total_nights := p_check_out - p_check_in;
    v_total_price := v_rate_per_night * v_total_nights;

    -- 8. Insert booking
    INSERT INTO bookings (
        guest_id,
        room_id,
        check_in,
        check_out,
        status,
        locked_rate_per_night,
        total_price,
        booked_at
    )
    VALUES (
        p_guest_id,
        p_room_id,
        p_check_in,
        p_check_out,
        'Pending Payment',
        v_rate_per_night,
        v_total_price,
        CURRENT_TIMESTAMP
    )
    RETURNING booking_id INTO v_new_booking_id;

    -- 9. Commit successful transaction
    COMMIT;

    p_success := TRUE;
    p_message := 'Booking created successfully. New booking ID: ' || v_new_booking_id;
END;
$$;


-- =========================================================
-- STEP 3.3: TRIGGER 1 - OVERLAP PREVENTION
-- =========================================================
-- Prevents INSERT or UPDATE if the same room has an existing
-- active booking with overlapping dates.
-- Overlap logic:
-- NEW.check_in < existing.check_out
-- AND
-- NEW.check_out > existing.check_in
-- =========================================================

CREATE OR REPLACE FUNCTION prevent_booking_overlap()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.status IN ('Pending Payment', 'Confirmed') THEN
        IF EXISTS (
            SELECT 1
            FROM bookings b
            WHERE b.room_id = NEW.room_id
              AND b.booking_id <> COALESCE(NEW.booking_id, -1)
              AND b.status IN ('Pending Payment', 'Confirmed')
              AND NEW.check_in < b.check_out
              AND NEW.check_out > b.check_in
        ) THEN
            RAISE EXCEPTION
                'Booking overlap detected: room % is already booked between % and %.',
                NEW.room_id,
                NEW.check_in,
                NEW.check_out;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_prevent_booking_overlap
BEFORE INSERT OR UPDATE
ON bookings
FOR EACH ROW
EXECUTE FUNCTION prevent_booking_overlap();


-- =========================================================
-- STEP 3.3: TRIGGER 2 - AUDIT LOGGING
-- =========================================================
-- Logs status changes in bookings table.
-- The audit_log table was already created in 01_schema_and_data.sql
-- using the exact structure required by the project.
-- =========================================================

CREATE OR REPLACE FUNCTION audit_booking_status_change()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF OLD.status IS DISTINCT FROM NEW.status THEN
        INSERT INTO audit_log (
            table_name,
            operation,
            old_status,
            new_status,
            changed_by,
            change_timestamp
        )
        VALUES (
            'bookings',
            'UPDATE',
            OLD.status,
            NEW.status,
            CURRENT_USER,
            CURRENT_TIMESTAMP
        );
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_audit_booking_status_change
AFTER UPDATE
ON bookings
FOR EACH ROW
EXECUTE FUNCTION audit_booking_status_change();


-- =========================================================
-- QUICK CHECKS
-- =========================================================

-- Test refund function:
SELECT calculate_refund(11, '2026-01-09 18:00:00') AS late_cancellation_refund;

SELECT calculate_refund(12, '2026-03-01 12:00:00') AS early_cancellation_refund;

-- Check triggers exist:
SELECT
    trigger_name,
    event_manipulation,
    event_object_table
FROM information_schema.triggers
WHERE event_object_table = 'bookings'
ORDER BY trigger_name;