-- =========================================================
-- DBMS CAPSTONE PROJECT
-- Grand Horizon Hotel Booking System
-- File: 01_schema_and_data.sql
-- =========================================================

BEGIN;

-- Drop tables if they already exist
DROP TABLE IF EXISTS payments CASCADE;
DROP TABLE IF EXISTS bookings CASCADE;
DROP TABLE IF EXISTS room_amenities CASCADE;
DROP TABLE IF EXISTS amenities CASCADE;
DROP TABLE IF EXISTS rooms CASCADE;
DROP TABLE IF EXISTS room_types CASCADE;
DROP TABLE IF EXISTS employees CASCADE;
DROP TABLE IF EXISTS guests CASCADE;
DROP TABLE IF EXISTS audit_log CASCADE;

-- =========================================================
-- 1. GUESTS
-- =========================================================
CREATE TABLE guests (
    guest_id SERIAL PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    phone VARCHAR(20),
    date_of_birth DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =========================================================
-- 2. ROOM TYPES
-- =========================================================
CREATE TABLE room_types (
    room_type_id SERIAL PRIMARY KEY,
    type_name VARCHAR(50) NOT NULL UNIQUE,
    base_price DECIMAL(10,2) NOT NULL CHECK (base_price > 0),
    capacity INT NOT NULL CHECK (capacity > 0),
    description TEXT
);

-- =========================================================
-- 3. ROOMS
-- =========================================================
CREATE TABLE rooms (
    room_id SERIAL PRIMARY KEY,
    room_number VARCHAR(10) NOT NULL UNIQUE,
    floor INT NOT NULL CHECK (floor > 0),
    room_type_id INT NOT NULL,
    room_status VARCHAR(20) NOT NULL DEFAULT 'Available',
    
    CONSTRAINT fk_rooms_room_type
        FOREIGN KEY (room_type_id)
        REFERENCES room_types(room_type_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT chk_room_status
        CHECK (room_status IN ('Available', 'Maintenance', 'Out of Service'))
);

-- =========================================================
-- 4. AMENITIES
-- =========================================================
CREATE TABLE amenities (
    amenity_id SERIAL PRIMARY KEY,
    amenity_name VARCHAR(50) NOT NULL UNIQUE
);

-- =========================================================
-- 5. ROOM AMENITIES JUNCTION TABLE
-- Composite primary key required by project
-- =========================================================
CREATE TABLE room_amenities (
    room_id INT NOT NULL,
    amenity_id INT NOT NULL,

    PRIMARY KEY (room_id, amenity_id),

    CONSTRAINT fk_room_amenities_room
        FOREIGN KEY (room_id)
        REFERENCES rooms(room_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    CONSTRAINT fk_room_amenities_amenity
        FOREIGN KEY (amenity_id)
        REFERENCES amenities(amenity_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE
);

-- =========================================================
-- 6. EMPLOYEES
-- =========================================================
CREATE TABLE employees (
    employee_id SERIAL PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    role VARCHAR(50) NOT NULL,
    manager_id INT,
    hire_date DATE NOT NULL,

    CONSTRAINT fk_employee_manager
        FOREIGN KEY (manager_id)
        REFERENCES employees(employee_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT chk_employee_manager_rule
        CHECK (
            (role = 'General Manager' AND manager_id IS NULL)
            OR
            (role <> 'General Manager' AND manager_id IS NOT NULL)
        )
);

-- =========================================================
-- 7. BOOKINGS
-- =========================================================
CREATE TABLE bookings (
    booking_id SERIAL PRIMARY KEY,
    guest_id INT NOT NULL,
    room_id INT NOT NULL,
    check_in DATE NOT NULL,
    check_out DATE NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'Pending Payment',
    locked_rate_per_night DECIMAL(10,2) NOT NULL CHECK (locked_rate_per_night > 0),
    total_price DECIMAL(10,2) NOT NULL CHECK (total_price >= 0),
    booked_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    canceled_at TIMESTAMP,

    CONSTRAINT fk_bookings_guest
        FOREIGN KEY (guest_id)
        REFERENCES guests(guest_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_bookings_room
        FOREIGN KEY (room_id)
        REFERENCES rooms(room_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT chk_booking_dates
        CHECK (check_out > check_in),

    CONSTRAINT chk_booking_status
        CHECK (status IN ('Pending Payment', 'Confirmed', 'Canceled', 'Completed'))
);

-- =========================================================
-- 8. PAYMENTS
-- =========================================================
CREATE TABLE payments (
    payment_id SERIAL PRIMARY KEY,
    booking_id INT NOT NULL,
    amount DECIMAL(10,2) NOT NULL CHECK (amount >= 0),
    payment_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    refund_amount DECIMAL(10,2) DEFAULT 0 CHECK (refund_amount >= 0),
    payment_status VARCHAR(30) NOT NULL,

    CONSTRAINT fk_payments_booking
        FOREIGN KEY (booking_id)
        REFERENCES bookings(booking_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    CONSTRAINT chk_payment_status
        CHECK (payment_status IN ('Paid', 'Pending', 'Refunded', 'Partially Refunded'))
);

-- =========================================================
-- 9. AUDIT LOG
-- Exact table requested in the project
-- =========================================================
CREATE TABLE audit_log (
    log_id SERIAL PRIMARY KEY,
    table_name VARCHAR(50) NOT NULL,
    operation VARCHAR(10) NOT NULL,
    old_status VARCHAR(20),
    new_status VARCHAR(20),
    changed_by VARCHAR(50) DEFAULT CURRENT_USER,
    change_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =========================================================
-- INDEXES
-- At least two explicitly defined indexes are required
-- =========================================================
CREATE INDEX idx_bookings_guest_id ON bookings(guest_id);
CREATE INDEX idx_bookings_room_id ON bookings(room_id);
CREATE INDEX idx_payments_booking_id ON payments(booking_id);
CREATE INDEX idx_employees_manager_id ON employees(manager_id);

-- =========================================================
-- INSERT DATA
-- =========================================================

-- Guests: 20 rows
INSERT INTO guests (guest_id, first_name, last_name, email, phone, date_of_birth) VALUES
(1, 'Aisha', 'Alharbi', 'aisha.alharbi@example.com', '0501111111', '1995-04-12'),
(2, 'Omar', 'Alqahtani', 'omar.alqahtani@example.com', '0502222222', '1989-08-25'),
(3, 'Sara', 'Almutairi', 'sara.almutairi@example.com', '0503333333', '1998-01-18'),
(4, 'Fahad', 'Alotaibi', 'fahad.alotaibi@example.com', '0504444444', '1985-11-02'),
(5, 'Noura', 'Alzahrani', 'noura.alzahrani@example.com', '0505555555', '1992-06-30'),
(6, 'Khalid', 'Alshehri', 'khalid.alshehri@example.com', '0506666666', '1990-10-10'),
(7, 'Lama', 'Alghamdi', 'lama.alghamdi@example.com', '0507777777', '1999-03-21'),
(8, 'Yousef', 'Alenzi', 'yousef.alenzi@example.com', '0508888888', '1987-12-09'),
(9, 'Huda', 'Alsubaie', 'huda.alsubaie@example.com', '0509999999', '1994-07-17'),
(10, 'Majed', 'Alrashid', 'majed.alrashid@example.com', '0511111111', '1986-05-14'),
(11, 'Reem', 'Alfahad', 'reem.alfahad@example.com', '0512222222', '1996-09-19'),
(12, 'Abdullah', 'Alsaud', 'abdullah.alsaud@example.com', '0513333333', '1984-02-27'),
(13, 'Maha', 'Alnasser', 'maha.alnasser@example.com', '0514444444', '1997-11-11'),
(14, 'Turki', 'Alhassan', 'turki.alhassan@example.com', '0515555555', '1991-01-05'),
(15, 'Dana', 'Almalki', 'dana.almalki@example.com', '0516666666', '1993-04-03'),
(16, 'Saad', 'Alshammari', 'saad.alshammari@example.com', '0517777777', '1988-08-08'),
(17, 'Rana', 'Alomar', 'rana.alomar@example.com', '0518888888', '1995-12-12'),
(18, 'Hassan', 'Alali', 'hassan.alali@example.com', '0519999999', '1983-03-15'),
(19, 'Mariam', 'Alkhaldi', 'mariam.alkhaldi@example.com', '0521111111', '2000-06-06'),
(20, 'Bader', 'Alfaisal', 'bader.alfaisal@example.com', '0522222222', '1990-09-29');

-- Room types: 5 rows
INSERT INTO room_types (room_type_id, type_name, base_price, capacity, description) VALUES
(1, 'Standard', 120.00, 2, 'Basic room with essential amenities.'),
(2, 'Deluxe', 180.00, 2, 'Larger room with improved view and comfort.'),
(3, 'Suite', 300.00, 4, 'Spacious suite with living area.'),
(4, 'Family', 240.00, 5, 'Room designed for families and groups.'),
(5, 'Executive', 400.00, 2, 'Premium executive room with luxury services.');

-- Rooms: 30 rows
INSERT INTO rooms (room_id, room_number, floor, room_type_id, room_status) VALUES
(1, '101', 1, 1, 'Available'),
(2, '102', 1, 1, 'Available'),
(3, '103', 1, 1, 'Available'),
(4, '104', 1, 2, 'Available'),
(5, '105', 1, 2, 'Available'),
(6, '201', 2, 1, 'Available'),
(7, '202', 2, 2, 'Available'),
(8, '203', 2, 3, 'Available'),
(9, '204', 2, 3, 'Available'),
(10, '205', 2, 4, 'Available'),
(11, '301', 3, 1, 'Available'),
(12, '302', 3, 2, 'Available'),
(13, '303', 3, 3, 'Available'),
(14, '304', 3, 4, 'Available'),
(15, '305', 3, 5, 'Available'),
(16, '401', 4, 1, 'Available'),
(17, '402', 4, 2, 'Available'),
(18, '403', 4, 3, 'Available'),
(19, '404', 4, 4, 'Available'),
(20, '405', 4, 5, 'Available'),
(21, '501', 5, 1, 'Available'),
(22, '502', 5, 2, 'Available'),
(23, '503', 5, 3, 'Maintenance'),
(24, '504', 5, 4, 'Available'),
(25, '505', 5, 5, 'Available'),
(26, '601', 6, 1, 'Available'),
(27, '602', 6, 2, 'Available'),
(28, '603', 6, 3, 'Available'),
(29, '604', 6, 4, 'Available'),
(30, '605', 6, 5, 'Out of Service');

-- Amenities: 10 rows
INSERT INTO amenities (amenity_id, amenity_name) VALUES
(1, 'Free Wi-Fi'),
(2, 'Smart TV'),
(3, 'Mini Bar'),
(4, 'Balcony'),
(5, 'Sea View'),
(6, 'Coffee Machine'),
(7, 'Work Desk'),
(8, 'Jacuzzi'),
(9, 'Kitchenette'),
(10, 'Extra Beds');

-- Room amenities: many-to-many data
INSERT INTO room_amenities (room_id, amenity_id) VALUES
(1,1),(1,2),(1,7),
(2,1),(2,2),(2,7),
(3,1),(3,2),(3,7),
(4,1),(4,2),(4,3),(4,6),
(5,1),(5,2),(5,3),(5,6),
(6,1),(6,2),(6,7),
(7,1),(7,2),(7,3),(7,6),
(8,1),(8,2),(8,3),(8,4),(8,5),
(9,1),(9,2),(9,3),(9,4),(9,5),
(10,1),(10,2),(10,9),(10,10),
(11,1),(11,2),(11,7),
(12,1),(12,2),(12,3),(12,6),
(13,1),(13,2),(13,4),(13,5),(13,8),
(14,1),(14,2),(14,9),(14,10),
(15,1),(15,2),(15,3),(15,5),(15,6),(15,8),
(16,1),(16,2),(16,7),
(17,1),(17,2),(17,3),(17,6),
(18,1),(18,2),(18,4),(18,5),(18,8),
(19,1),(19,2),(19,9),(19,10),
(20,1),(20,2),(20,3),(20,5),(20,6),(20,8),
(21,1),(21,2),(21,7),
(22,1),(22,2),(22,3),(22,6),
(23,1),(23,2),(23,4),(23,5),
(24,1),(24,2),(24,9),(24,10),
(25,1),(25,2),(25,3),(25,5),(25,6),(25,8),
(26,1),(26,2),(26,7),
(27,1),(27,2),(27,3),(27,6),
(28,1),(28,2),(28,4),(28,5),
(29,1),(29,2),(29,9),(29,10),
(30,1),(30,2),(30,3),(30,5),(30,6);

-- Employees: 15 rows
INSERT INTO employees (employee_id, first_name, last_name, role, manager_id, hire_date) VALUES
(1, 'Mansour', 'Alkhatib', 'General Manager', NULL, '2018-01-10'),
(2, 'Layla', 'Alharthi', 'Operations Manager', 1, '2019-03-12'),
(3, 'Sultan', 'Alqarni', 'Finance Manager', 1, '2019-05-20'),
(4, 'Heba', 'Alasmari', 'Front Desk Manager', 2, '2020-02-15'),
(5, 'Rakan', 'Almutlaq', 'Housekeeping Manager', 2, '2020-07-01'),
(6, 'Mona', 'Alotaibi', 'Reservation Supervisor', 4, '2021-01-18'),
(7, 'Faisal', 'Alharbi', 'Front Desk Agent', 6, '2022-04-10'),
(8, 'Ghada', 'Alzahrani', 'Front Desk Agent', 6, '2023-06-05'),
(9, 'Nawaf', 'Alshehri', 'Accountant', 3, '2021-09-25'),
(10, 'Amal', 'Alghamdi', 'Auditor', 3, '2022-11-14'),
(11, 'Saleh', 'Alenzi', 'Housekeeping Supervisor', 5, '2021-05-19'),
(12, 'Ruba', 'Alsubaie', 'Housekeeper', 11, '2023-02-09'),
(13, 'Bandar', 'Alrashid', 'Maintenance Supervisor', 2, '2020-10-22'),
(14, 'Noor', 'Alfahad', 'Maintenance Technician', 13, '2024-01-08'),
(15, 'Yara', 'Alnasser', 'Reservation Agent', 6, '2024-03-17');

-- Bookings: 40 rows
INSERT INTO bookings 
(booking_id, guest_id, room_id, check_in, check_out, status, locked_rate_per_night, total_price, booked_at, canceled_at)
VALUES
(1, 3, 1, '2025-06-05', '2025-06-08', 'Completed', 120.00, 360.00, '2025-05-20 10:00:00', NULL),
(2, 4, 8, '2025-07-10', '2025-07-12', 'Completed', 300.00, 600.00, '2025-06-15 11:30:00', NULL),
(3, 5, 10, '2025-08-03', '2025-08-07', 'Completed', 240.00, 960.00, '2025-07-01 09:15:00', NULL),
(4, 6, 15, '2025-09-20', '2025-09-22', 'Completed', 400.00, 800.00, '2025-08-10 14:20:00', NULL),
(5, 7, 12, '2025-12-24', '2025-12-27', 'Completed', 180.00, 540.00, '2025-11-02 08:45:00', NULL),
(6, 8, 20, '2026-01-05', '2026-01-08', 'Completed', 400.00, 1200.00, '2025-12-01 16:10:00', NULL),
(7, 9, 6, '2026-02-14', '2026-02-16', 'Completed', 120.00, 240.00, '2026-01-20 13:05:00', NULL),
(8, 10, 14, '2026-03-01', '2026-03-05', 'Completed', 240.00, 960.00, '2026-02-04 12:00:00', NULL),
(9, 11, 25, '2026-04-01', '2026-04-03', 'Completed', 400.00, 800.00, '2026-03-11 10:40:00', NULL),

(10, 2, 3, '2025-10-05', '2025-10-08', 'Canceled', 120.00, 360.00, '2025-09-12 09:00:00', '2025-09-25 15:00:00'),
(11, 2, 7, '2026-01-10', '2026-01-13', 'Canceled', 180.00, 540.00, '2025-12-20 10:00:00', '2026-01-09 18:00:00'),
(12, 2, 13, '2026-03-12', '2026-03-15', 'Canceled', 300.00, 900.00, '2026-02-10 11:00:00', '2026-03-01 12:00:00'),
(13, 12, 18, '2026-05-10', '2026-05-12', 'Canceled', 300.00, 600.00, '2026-04-20 09:00:00', '2026-05-07 10:00:00'),

(14, 13, 22, '2026-05-20', '2026-05-22', 'Pending Payment', 180.00, 360.00, '2026-05-01 12:00:00', NULL),
(15, 14, 24, '2026-05-25', '2026-05-28', 'Confirmed', 240.00, 720.00, '2026-05-02 14:00:00', NULL),

(16, 1, 1, '2026-06-01', '2026-06-03', 'Confirmed', 120.00, 240.00, '2026-05-03 10:30:00', NULL),
(17, 1, 2, '2026-06-10', '2026-06-12', 'Confirmed', 120.00, 240.00, '2026-05-03 10:35:00', NULL),
(18, 1, 4, '2026-07-01', '2026-07-04', 'Pending Payment', 180.00, 540.00, '2026-05-03 10:40:00', NULL),

(19, 15, 5, '2026-06-15', '2026-06-18', 'Confirmed', 180.00, 540.00, '2026-05-04 09:10:00', NULL),
(20, 16, 8, '2026-06-20', '2026-06-24', 'Confirmed', 300.00, 1200.00, '2026-05-04 09:30:00', NULL),
(21, 17, 10, '2026-07-05', '2026-07-10', 'Confirmed', 240.00, 1200.00, '2026-05-05 10:00:00', NULL),
(22, 18, 15, '2026-07-12', '2026-07-15', 'Confirmed', 400.00, 1200.00, '2026-05-05 11:00:00', NULL),
(23, 19, 20, '2026-08-01', '2026-08-04', 'Pending Payment', 400.00, 1200.00, '2026-05-06 12:15:00', NULL),
(24, 20, 25, '2026-08-10', '2026-08-13', 'Confirmed', 400.00, 1200.00, '2026-05-06 13:00:00', NULL),
(25, 3, 6, '2026-09-01', '2026-09-05', 'Confirmed', 120.00, 480.00, '2026-05-07 08:00:00', NULL),
(26, 4, 11, '2026-09-10', '2026-09-13', 'Pending Payment', 120.00, 360.00, '2026-05-07 08:30:00', NULL),
(27, 5, 16, '2026-10-01', '2026-10-03', 'Confirmed', 120.00, 240.00, '2026-05-07 09:00:00', NULL),
(28, 6, 21, '2026-10-15', '2026-10-18', 'Confirmed', 120.00, 360.00, '2026-05-07 09:30:00', NULL),
(29, 7, 26, '2026-11-01', '2026-11-04', 'Pending Payment', 120.00, 360.00, '2026-05-08 10:00:00', NULL),
(30, 8, 27, '2026-11-12', '2026-11-16', 'Confirmed', 180.00, 720.00, '2026-05-08 10:30:00', NULL),
(31, 9, 28, '2026-12-20', '2026-12-23', 'Confirmed', 300.00, 900.00, '2026-05-08 11:00:00', NULL),
(32, 10, 29, '2026-12-24', '2026-12-28', 'Pending Payment', 240.00, 960.00, '2026-05-08 11:30:00', NULL),
(33, 11, 30, '2026-12-29', '2027-01-02', 'Confirmed', 400.00, 1600.00, '2026-05-08 12:00:00', NULL),

(34, 12, 9, '2026-04-20', '2026-04-22', 'Completed', 300.00, 600.00, '2026-03-20 09:00:00', NULL),
(35, 13, 17, '2026-04-22', '2026-04-25', 'Completed', 180.00, 540.00, '2026-03-21 10:00:00', NULL),
(36, 14, 19, '2026-04-26', '2026-04-28', 'Completed', 240.00, 480.00, '2026-03-22 11:00:00', NULL),

(37, 15, 23, '2026-06-01', '2026-06-05', 'Canceled', 300.00, 1200.00, '2026-04-01 09:00:00', '2026-05-01 09:00:00'),
(38, 16, 24, '2026-06-05', '2026-06-08', 'Canceled', 240.00, 720.00, '2026-04-02 10:00:00', '2026-06-04 12:00:00'),
(39, 17, 3, '2026-04-05', '2026-04-07', 'Completed', 120.00, 240.00, '2026-03-01 10:00:00', NULL),
(40, 18, 7, '2026-04-08', '2026-04-11', 'Completed', 180.00, 540.00, '2026-03-02 10:00:00', NULL);

-- Payments: 40 rows
INSERT INTO payments 
(payment_id, booking_id, amount, payment_date, refund_amount, payment_status)
VALUES
(1, 1, 360.00, '2025-05-20 10:10:00', 0.00, 'Paid'),
(2, 2, 600.00, '2025-06-15 11:40:00', 0.00, 'Paid'),
(3, 3, 960.00, '2025-07-01 09:25:00', 0.00, 'Paid'),
(4, 4, 800.00, '2025-08-10 14:30:00', 0.00, 'Paid'),
(5, 5, 540.00, '2025-11-02 08:55:00', 0.00, 'Paid'),
(6, 6, 1200.00, '2025-12-01 16:20:00', 0.00, 'Paid'),
(7, 7, 240.00, '2026-01-20 13:15:00', 0.00, 'Paid'),
(8, 8, 960.00, '2026-02-04 12:10:00', 0.00, 'Paid'),
(9, 9, 800.00, '2026-03-11 10:50:00', 0.00, 'Paid'),

(10, 10, 360.00, '2025-09-12 09:10:00', 360.00, 'Refunded'),
(11, 11, 540.00, '2025-12-20 10:10:00', 270.00, 'Partially Refunded'),
(12, 12, 900.00, '2026-02-10 11:10:00', 900.00, 'Refunded'),
(13, 13, 600.00, '2026-04-20 09:10:00', 600.00, 'Refunded'),

(14, 14, 0.00, '2026-05-01 12:10:00', 0.00, 'Pending'),
(15, 15, 720.00, '2026-05-02 14:10:00', 0.00, 'Paid'),

(16, 16, 240.00, '2026-05-03 10:45:00', 0.00, 'Paid'),
(17, 17, 240.00, '2026-05-03 10:50:00', 0.00, 'Paid'),
(18, 18, 0.00, '2026-05-03 10:55:00', 0.00, 'Pending'),

(19, 19, 540.00, '2026-05-04 09:20:00', 0.00, 'Paid'),
(20, 20, 1200.00, '2026-05-04 09:40:00', 0.00, 'Paid'),
(21, 21, 1200.00, '2026-05-05 10:10:00', 0.00, 'Paid'),
(22, 22, 1200.00, '2026-05-05 11:10:00', 0.00, 'Paid'),
(23, 23, 0.00, '2026-05-06 12:25:00', 0.00, 'Pending'),
(24, 24, 1200.00, '2026-05-06 13:10:00', 0.00, 'Paid'),
(25, 25, 480.00, '2026-05-07 08:10:00', 0.00, 'Paid'),
(26, 26, 0.00, '2026-05-07 08:40:00', 0.00, 'Pending'),
(27, 27, 240.00, '2026-05-07 09:10:00', 0.00, 'Paid'),
(28, 28, 360.00, '2026-05-07 09:40:00', 0.00, 'Paid'),
(29, 29, 0.00, '2026-05-08 10:10:00', 0.00, 'Pending'),
(30, 30, 720.00, '2026-05-08 10:40:00', 0.00, 'Paid'),

(31, 31, 900.00, '2026-05-08 11:10:00', 0.00, 'Paid'),

(32, 32, 0.00, '2026-05-08 11:40:00', 0.00, 'Pending'),

(33, 33, 1600.00, '2026-05-08 12:10:00', 0.00, 'Paid'),

(34, 34, 600.00, '2026-03-20 09:10:00', 0.00, 'Paid'),

(35, 35, 540.00, '2026-03-21 10:10:00', 0.00, 'Paid'),

(36, 36, 480.00, '2026-03-22 11:10:00', 0.00, 'Paid'),

(37, 37, 1200.00, '2026-04-01 09:10:00', 1200.00, 'Refunded'),

(38, 38, 720.00, '2026-04-02 10:10:00', 360.00, 'Partially Refunded'),

(39, 39, 240.00, '2026-03-01 10:10:00', 0.00, 'Paid'),

(40, 40, 540.00, '2026-03-02 10:10:00', 0.00, 'Paid');

-- Fix serial sequences after inserting manual IDs

SELECT setval(pg_get_serial_sequence('guests', 'guest_id'), (SELECT MAX(guest_id) FROM guests));

SELECT setval(pg_get_serial_sequence('room_types', 'room_type_id'), (SELECT MAX(room_type_id) FROM room_types));

SELECT setval(pg_get_serial_sequence('rooms', 'room_id'), (SELECT MAX(room_id) FROM rooms));

SELECT setval(pg_get_serial_sequence('amenities', 'amenity_id'), (SELECT MAX(amenity_id) FROM amenities));

SELECT setval(pg_get_serial_sequence('employees', 'employee_id'), (SELECT MAX(employee_id) FROM employees));

SELECT setval(pg_get_serial_sequence('bookings', 'booking_id'), (SELECT MAX(booking_id) FROM bookings));

SELECT setval(pg_get_serial_sequence('payments', 'payment_id'), (SELECT MAX(payment_id) FROM payments));

COMMIT;

-- =========================================================

-- QUICK CHECKS

-- Run these after the script to confirm data was inserted

-- =========================================================

SELECT 'guests' AS table_name, COUNT(*) AS total_rows FROM guests

UNION ALL

SELECT 'room_types', COUNT(*) FROM room_types

UNION ALL

SELECT 'rooms', COUNT(*) FROM rooms

UNION ALL

SELECT 'amenities', COUNT(*) FROM amenities

UNION ALL

SELECT 'room_amenities', COUNT(*) FROM room_amenities

UNION ALL

SELECT 'employees', COUNT(*) FROM employees

UNION ALL

SELECT 'bookings', COUNT(*) FROM bookings

UNION ALL

SELECT 'payments', COUNT(*) FROM payments;