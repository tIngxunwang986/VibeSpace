# VibeSpace

A Steam-inspired game discovery platform built with Flask and MySQL.

**Group:** CrossCurrent (Tingxun Wang & Ahmed Furkhan)
**Course:** CS 5200 Database Management — Spring 2026

## Setup

### 1. Database
```bash
mysql -u root -p < vibespace_schema.sql
mysql -u root -p < vibespace_data.sql
mysql -u root -p < vibespace_procs.sql
```

### 2. Application
1. Open `app.py` and fill in your MySQL password in the `DB_CONFIG` dictionary
2. `pip install flask mysql-connector-python`
3. `python3 app.py`
4. Open http://127.0.0.1:5000

## Test Accounts

| Username | Password |
|----------|----------|
| ahmed_f | pass1234 |
| tingxun_w | secureXX |
| gamer_nova | nova9999 |

## Details

See `CrossCurrent_final_report.pdf` for full documentation.
