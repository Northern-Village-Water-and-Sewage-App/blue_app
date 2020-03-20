import psycopg2
import pandas as pd

USER = "postgres"
PASSWORD = "abcd1234"
HOST = "13.59.214.194"
PORT = "5432"
DATABASE = "postgres"


def _get_connection():
    return psycopg2.connect(user=USER,
                            password=PASSWORD,
                            host=HOST,
                            port=PORT,
                            database=DATABASE)


def run_select(query):
    conn = _get_connection()
    cursor = conn.cursor()
    cursor.execute(query)
    return cursor.fetchall()


def execute_command(query):
    conn = _get_connection()
    cursor = conn.cursor()
    cursor.execute(query)
    # cursor.fetchone()
    conn.commit()
    conn.close()

def run_select_for_json(query):
    df = pd.read_sql_query(query, _get_connection())
    return df.to_json(orient='records')


if __name__ == "__main__":
    print(run_select_for_json("select * from tank_model;"))
