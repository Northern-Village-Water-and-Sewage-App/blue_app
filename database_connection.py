import psycopg2
import pandas as pd

USER = "postgres"
PASSWORD = "xyz9uDFshJduKqXbC9efMjqM"
HOST = "0.0.0.0"
PORT = "32032"
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
    conn.commit()
    conn.close()


def run_select_for_json(query):
    df = pd.read_sql_query(query, _get_connection())
    return df.to_json(orient='records')


def get_query_result_as_df(query):
    return pd.read_sql_query(query, _get_connection())


if __name__ == "__main__":
    print(get_query_result_as_df('select * from app_worklist').to_json())
