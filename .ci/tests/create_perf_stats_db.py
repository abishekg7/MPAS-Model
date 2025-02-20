import sqlite3
import sys

def create_connection(db_file):
    """Create a database connection to the SQLite database specified by db_file."""
    conn = None
    try:
        conn = sqlite3.connect(db_file)
        print(f"Connected to SQLite database: {db_file}")
    except sqlite3.Error as e:
        print(e)
    return conn

def create_table(conn):
    """Create a table in the SQLite database."""
    try:
        sql_create_table = """ CREATE TABLE IF NOT EXISTS perf_data (
                                id integer  PRIMARY KEY AUTOINCREMENT,
                                date text DEFAULT CURRENT_TIMESTAMP,
                                testcase text NOT NULL,
                                machine text NOT NULL,
                                device text NOT NULL,
                                compiler text NOT NULL,
                                mpas_version text NOT NULL,
                                min_time real NOT NULL,
                                max_time real NOT NULL,
                                avg_time real NOT NULL,
                                stdev_time real NOT NULL
                            ); """
        cursor = conn.cursor()
        cursor.execute(sql_create_table)
        print("Table created successfully")
    except sqlite3.Error as e:
        print(e)


def main(db_file):

    # Create a database connection
    conn = create_connection(db_file)

    if conn is not None:
        # Create table
        create_table(conn)

        # Close the connection
        conn.close()
    else:
        print("Error! Cannot create the database connection.")

if __name__ == '__main__':
    if len(sys.argv) < 1:
        print("Usage: python create_perf_stats_db.py <db_file>")
    else:
        db_file = sys.argv[1]        
        main(db_file)