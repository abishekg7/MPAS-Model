import sqlite3
import sys
from datetime import datetime, timedelta
import math
import ast
import statistics as st

def create_connection(db_file):
    """Create a database connection to the SQLite database specified by db_file."""
    conn = None
    try:
        conn = sqlite3.connect(db_file)
        print(f"Connected to SQLite database: {db_file}")
    except sqlite3.Error as e:
        print(e)
    return conn

def print_last_five_days(conn):
    """Query all fields from the perf_data table for the last 5 days and report the average."""
    try:
        cursor = conn.cursor()
        five_days_ago = (datetime.now() - timedelta(days=5)).strftime('%Y-%m-%d %H:%M:%S')
        cursor.execute("""
            SELECT * FROM perf_data
            WHERE date >= ?
        """, (five_days_ago,))
        rows = cursor.fetchall()
        col_names = list(map(lambda x: x[0], cursor.description))
        
        if rows:
            print(rows)
            avg_times = [row[col_names.index('avg_time')] for row in rows]
            var_times = [row[col_names.index('stdev_time')]**2 for row in rows]
            overall_avg_time = sum(avg_times) / len(avg_times)
            overall_stdev_time = math.sqrt(sum(var_times) / len(avg_times))
            print(f"Average mean, std_dev for the last 5 days: {overall_avg_time} {overall_stdev_time}")
        else:
            print("No data found for the last 5 days.")
        
        cursor.close()
    except sqlite3.Error as e:
        print(e)    

def query_avg_time(conn, testcase, machine, device, compiler):
    """Query the avg_time from the perf_data table for the last 5 days and report the average."""
    try:
        cursor = conn.cursor()
        five_days_ago = (datetime.now() - timedelta(days=5)).strftime('%Y-%m-%d %H:%M:%S')
        cursor.execute("""
            SELECT * FROM perf_data
            WHERE date >= ? AND testcase = ? AND machine = ? AND device = ? AND compiler = ?
        """, (five_days_ago,testcase, machine, device, compiler))
        rows = cursor.fetchall()
        col_names = list(map(lambda x: x[0], cursor.description))
        if rows:
            print(rows)
            avg_times = [row[col_names.index('avg_time')] for row in rows]
            var_times = [row[col_names.index('stdev_time')]**2 for row in rows]
            overall_avg_time = sum(avg_times) / len(avg_times)
            overall_stdev_time = math.sqrt(sum(var_times) / len(avg_times))
            print(f"Average mean, std_dev for the last 5 days: {overall_avg_time} {overall_stdev_time}")
        else:
            print("No data found for the last 5 days.")
        
        cursor.close()

        return [overall_avg_time, overall_stdev_time]
    except sqlite3.Error as e:
        print(e)

def compare_to_ref(conn, testcase, machine, device, compiler, avg_time, stdev_time):

    [mean_ref, stdev_ref] = query_avg_time(conn, testcase, machine, device, compiler)

    if avg_time > mean_ref + 2 * stdev_ref:
        print(f"Performance regression detected for {testcase} on {machine} using {device} with {compiler}.")

def main(action, db_file, testcase, machine = None, device = None, compiler = None, avg_time = None, stdev_time = None):
    # Create a database connection
    conn = create_connection(db_file)

    if conn is not None:
        if action == "compare_to_ref":
            compare_to_ref(conn, testcase, machine, device, compiler, avg_time, stdev_time)
        elif action == "ls":
            print_last_five_days(conn)
        else:
            print(f"Unknown action: {action}")
        
        # Close the connection
        conn.close()
    else:
        print("Error! Cannot create the database connection.")

if __name__ == '__main__':
    if len(sys.argv) < 3:
        print("Usage: python query_avg_time.py <action> <db_file> <testcase>")
    else:
        action = sys.argv[1]
        db_file = sys.argv[2]
        testcase = sys.argv[3]
        machine = sys.argv[4]
        device = sys.argv[5]
        compiler = sys.argv[6]
        timings_arr_str =sys.argv[7].split(',')
        
        timings_arr = [ast.literal_eval(i.replace(" ", ",")) for i in timings_arr_str]
        avg_time = st.mean(timings_arr) 
        stdev_time = st.pstdev(timings_arr)

        print(f"Current mean, std_dev : {avg_time} {stdev_time}")

        main(action, db_file, testcase, machine, device, compiler, avg_time, stdev_time)