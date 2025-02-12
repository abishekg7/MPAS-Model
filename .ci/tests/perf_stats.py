import sqlite3
import sys
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


def insert_data(conn, data):
    """Insert data into the table."""
    try:
        #sql_insert_data = """INSERT INTO test_data (te, value) VALUES (?, ?);"""
        sql_insert_data = """ INSERT INTO perf_data (testcase, machine, device,
                            compiler, mpas_version, min_time, max_time, avg_time, stdev_time)
                            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ? );"""
        cursor = conn.cursor()
        cursor.execute(sql_insert_data, data)
        conn.commit()
        print("Data inserted successfully")
    except sqlite3.Error as e:
        print(e)

def main(db_file, testcase, machine, device, compiler, commit, min_time, max_time, avg_time, stdev_time):
    # Create a database connection
    conn = create_connection(db_file)

    if conn is not None:
        # Data to be inserted
        data = (testcase, machine, device, compiler, commit, min_time, max_time, avg_time, stdev_time)
        
        # Insert data
        insert_data(conn, data)
        
        # Close the connection
        conn.close()
    else:
        print("Error! Cannot create the database connection.")

if __name__ == '__main__':
    if len(sys.argv) < 7:
        print("""Usage: python perf_stats.py <action> <db_file> [testcase] 
            [machine] [device] [compiler] [commit] [comma separated timings]""")
    else:
        db_file = sys.argv[1]
        testcase = sys.argv[2]
        machine = sys.argv[3]
        device = sys.argv[4]
        compiler = sys.argv[5]
        commit = sys.argv[6]
        timings_arr_str =sys.argv[7].split(',')
        # avoiding numpy for now. 
        # solution from https://stackoverflow.com/questions/72694568/how-to-convert-a-string-array-to-float-array
        timings_arr = [ast.literal_eval(i.replace(" ", ",")) for i in timings_arr_str]

        min_time = min(timings_arr)
        max_time = max(timings_arr)
        #avg_time = sum(timings_arr) / len(timings_arr)
        avg_time = st.mean(timings_arr) 
        stdev_time = st.pstdev(timings_arr)

        main(db_file, testcase, machine, device, compiler, commit, min_time, max_time, avg_time, stdev_time)