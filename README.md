````Markdown

# Grand Horizon Hotel Booking System

## Project Overview

This project is a PostgreSQL-backed hotel booking system for Grand Horizon Hotel. It manages guests, rooms, room types, employees, bookings, payments, cancellation refunds, audit logging, and room availability.

## Technologies Used

- PostgreSQL
- Python
- psycopg2
- python-dotenv
- pgAdmin
- PyCharm

## How to Run SQL Files

Run the files in this order:

1. 01_schema_and_data.sql
2. 02_queries.sql
3. 03_procedures_triggers.sql
4. 03_test.sql

## How to Run the Python App

Go to the 04_application folder.

Install dependencies:

```bash
pip install -r requirements.txt
```

````

Create a .env file using .env.example as a template:

```env
DB_HOST=localhost
DB_PORT=5432
DB_NAME=grand_horizon_db
DB_USER=postgres
DB_PASSWORD=your_password_here
```

Run the app:

```bash
py app.py
```

App Menu

1. View all active bookings
2. Add a new guest
3. Update a guest’s email address
4. Cancel a booking
5. Book a room
6. Run the Frequent Cancellers Report
7. Exit

Security Note

The real .env file is not included in the submission because it contains private database credentials.
