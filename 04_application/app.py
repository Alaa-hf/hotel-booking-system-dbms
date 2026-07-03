from psycopg2 import errors

from db import get_connection, release_connection, close_pool


def print_rows(columns, rows):
    if not rows:
        print("\nNo records found.\n")
        return

    print()
    print(" | ".join(columns))
    print("-" * 100)

    for row in rows:
        formatted_row = []
        for value in row:
            if value is None:
                formatted_row.append("NULL")
            else:
                formatted_row.append(str(value))

        print(" | ".join(formatted_row))

    print()


def view_active_bookings():
    conn = get_connection()

    try:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT
                    b.booking_id,
                    g.first_name || ' ' || g.last_name AS guest_name,
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
                WHERE b.status IN ('Pending Payment', 'Confirmed')
                  AND b.check_out > CURRENT_DATE
                ORDER BY b.check_in;
            """)

            rows = cur.fetchall()
            columns = [desc[0] for desc in cur.description]
            print_rows(columns, rows)

    except Exception as e:
        print(f"\nUnexpected error while viewing bookings: {e}\n")

    finally:
        release_connection(conn)


def add_new_guest():
    first_name = input("First name: ").strip()
    last_name = input("Last name: ").strip()
    email = input("Email: ").strip()
    phone = input("Phone: ").strip()
    date_of_birth = input("Date of birth YYYY-MM-DD, or leave empty: ").strip()

    if date_of_birth == "":
        date_of_birth = None

    conn = get_connection()

    try:
        with conn.cursor() as cur:
            cur.execute("""
                INSERT INTO guests (
                    first_name,
                    last_name,
                    email,
                    phone,
                    date_of_birth
                )
                VALUES (%s, %s, %s, %s, %s)
                RETURNING guest_id;
            """, (first_name, last_name, email, phone, date_of_birth))

            guest_id = cur.fetchone()[0]
            conn.commit()
            print(f"\nGuest added successfully. New guest ID: {guest_id}\n")

    except errors.UniqueViolation:
        conn.rollback()
        print("\nError: That email is already registered.\n")

    except errors.CheckViolation:
        conn.rollback()
        print("\nError: Invalid guest data.\n")

    except Exception as e:
        conn.rollback()
        print(f"\nUnexpected error while adding guest: {e}\n")

    finally:
        release_connection(conn)


def update_guest_email():
    guest_id = input("Guest ID: ").strip()
    new_email = input("New email: ").strip()

    conn = get_connection()

    try:
        with conn.cursor() as cur:
            cur.execute("""
                UPDATE guests
                SET email = %s
                WHERE guest_id = %s::INT;
            """, (new_email, guest_id))

            if cur.rowcount == 0:
                conn.rollback()
                print("\nError: Guest ID not found.\n")
            else:
                conn.commit()
                print("\nGuest email updated successfully.\n")

    except errors.UniqueViolation:
        conn.rollback()
        print("\nError: That email is already registered.\n")

    except Exception as e:
        conn.rollback()
        print(f"\nUnexpected error while updating email: {e}\n")

    finally:
        release_connection(conn)


def cancel_booking():
    booking_id = input("Booking ID to cancel: ").strip()

    if not booking_id.isdigit():
        print("\nError: Booking ID must be a number.\n")
        return

    conn = get_connection()

    try:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT status
                FROM bookings
                WHERE booking_id = %s::INT
                FOR UPDATE;
            """, (booking_id,))

            booking = cur.fetchone()

            if not booking:
                conn.rollback()
                print("\nError: Booking ID not found.\n")
                return

            current_status = booking[0]

            if current_status == "Canceled":
                conn.rollback()
                print("\nError: This booking is already canceled.\n")
                return

            cur.execute("""
                SELECT calculate_refund(%s::INT, CURRENT_TIMESTAMP::TIMESTAMP);
            """, (booking_id,))

            refund_amount = cur.fetchone()[0]

            cur.execute("""
                UPDATE bookings
                SET
                    status = 'Canceled',
                    canceled_at = CURRENT_TIMESTAMP
                WHERE booking_id = %s::INT;
            """, (booking_id,))

            cur.execute("""
                UPDATE payments
                SET
                    refund_amount = %s,
                    payment_status =
                        CASE
                            WHEN amount = %s THEN 'Refunded'
                            WHEN %s > 0 THEN 'Partially Refunded'
                            ELSE payment_status
                        END
                WHERE booking_id = %s::INT;
            """, (refund_amount, refund_amount, refund_amount, booking_id))

            conn.commit()
            print(f"\nBooking canceled successfully. Refund amount: {refund_amount}\n")

    except Exception as e:
        conn.rollback()
        print(f"\nUnexpected error while canceling booking: {e}\n")

    finally:
        release_connection(conn)


def book_room_menu():
    guest_id = input("Guest ID: ").strip()
    room_id = input("Room ID: ").strip()
    check_in = input("Check-in date YYYY-MM-DD: ").strip()
    check_out = input("Check-out date YYYY-MM-DD: ").strip()

    conn = get_connection()
    old_autocommit = conn.autocommit

    try:
        conn.autocommit = True

        with conn.cursor() as cur:
            cur.execute("""
                CALL book_room(
                    %s::INT,
                    %s::INT,
                    %s::DATE,
                    %s::DATE,
                    NULL,
                    NULL
                );
            """, (guest_id, room_id, check_in, check_out))

            result = cur.fetchone()

            if result:
                success, message = result
                print(f"\nSuccess: {success}")
                print(f"Message: {message}\n")
            else:
                print("\nProcedure executed.\n")

    except errors.CheckViolation:
        print("\nError: Invalid booking data. Please check the dates and values.\n")

    except Exception as e:
        print(f"\nBooking error: {e}\n")

    finally:
        conn.autocommit = old_autocommit
        release_connection(conn)

def frequent_cancellers_report():
    conn = get_connection()

    try:
        with conn.cursor() as cur:
            cur.execute("""
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
            """)

            rows = cur.fetchall()
            columns = [desc[0] for desc in cur.description]
            print_rows(columns, rows)

    except Exception as e:
        print(f"\nUnexpected error while running report: {e}\n")

    finally:
        release_connection(conn)


def show_menu():
    print("""
========================================
 Grand Horizon Hotel Booking System
========================================
1. View all active bookings
2. Add a new guest
3. Update a guest's email address
4. Cancel a booking
5. Book a room
6. Run the Frequent Cancellers Report
7. Exit
""")


def main():
    while True:
        show_menu()
        choice = input("Choose an option: ").strip()

        if choice == "1":
            view_active_bookings()
        elif choice == "2":
            add_new_guest()
        elif choice == "3":
            update_guest_email()
        elif choice == "4":
            cancel_booking()
        elif choice == "5":
            book_room_menu()
        elif choice == "6":
            frequent_cancellers_report()
        elif choice == "7":
            print("\nGoodbye.")
            close_pool()
            break
        else:
            print("\nInvalid choice. Please choose a number from 1 to 7.\n")


if __name__ == "__main__":
    main()