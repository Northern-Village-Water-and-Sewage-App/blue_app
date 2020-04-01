#!flask/bin/python
from flask import Flask, jsonify
from database_connection import run_select_for_json, execute_command, get_query_result_as_df, pd

app = Flask(__name__)


@app.route('/')
def index():
    return jsonify(hello="Hello, World!")


@app.route('/add_report/<complaint_type_fk>/<company_fk>/<complaint>/')
def add_report(complaint_type_fk, company_fk, complaint):
    execute_command(
        f'insert into report (complaint_type_fk, company_fk, complaint) values ({complaint_type_fk}, {company_fk}, {complaint})')


@app.route('/get_user/<username>', methods=['GET'])
def get_user(username):
    return run_select_for_json(
        f'select * from app_login where username = \'{username}\';')


@app.route('/get_tank_info/<username>', methods=['GET'])
def get_tank_info(username):
    return run_select_for_json(
        f'select '
        f'username, '
        f'status as sewage_tank_status, '
        f'to_char(str.timestamp, \'DD Mon YYYY HH:MI:SSPM\') as sewage_tank_timestamp, '
        f'wtr.current_height as water_tank_height, '
        f'to_char(wtr.timestamp, \'DD Mon YYYY HH:MI:SSPM\') as water_tank_timestamp '
        f'from residents '
        f'join sewage_tank_readings str on residents.pk = str.tank_owner_fk '
        f'join water_tank_readings wtr on residents.pk = wtr.tank_owner_fk '
        f'where username = \'{username}\' '
        f'order by str.timestamp, wtr.timestamp desc '
        f'limit 1')


@app.route('/get_work_list/', methods=['GET'])
def get_work_list():
    df = get_query_result_as_df('select * from app_worklist')
    max_times = df.groupby(['username', 'tank_type']).timestamp.transform(max)
    return df.loc[df.timestamp == max_times].to_json(orient='records')


@app.route('/add_manager/<user_name>/<user_pin>')
def add_manager(user_name, user_pin):
    execute_command(
        f"insert into managers (username, pin) values ('{user_name}', '{user_pin}')")
    return run_select_for_json('select * from managers;')


@app.route('/add_driver/<user_name>/<user_pin>')
def add_driver(user_name, user_pin):
    execute_command(
        f"insert into drivers (username, pin) values ('{user_name}', '{user_pin}')")
    return run_select_for_json('select * from drivers;')


@app.route('/add_resident/<user_name>/<house_number>/<user_pin>/<water_tank_fk>/<sewage_tank_fk>')
def add_resident(user_name, house_number, user_pin, water_tank_fk, sewage_tank_fk):
    execute_command(
        f"insert into residents (username, house_number, pin, water_tank_fk, sewage_tank_fk) values ('{user_name}', {house_number}, '{user_pin}', {water_tank_fk}, {sewage_tank_fk})")
    return run_select_for_json('select * from residents;')


@app.route('/remove_resident/<resident_user_name>')
def remove_resident(resident_user_name):
    execute_command(f'delete from residents where username = \'{resident_user_name}\'')
    return run_select_for_json('select * from residents;')


@app.route('/remove_manager/<manager_user_name>')
def remove_manager(manager_user_name):
    execute_command(f'delete from managers where username = \'{manager_user_name}\'')
    return run_select_for_json('select * from managers;')


@app.route('/remove_driver/<driver_user_name>')
def remove_driver(driver_user_name):
    execute_command(f'delete from drivers where username = \'{driver_user_name}\'')
    return run_select_for_json('select * from drivers;')


if __name__ == '__main__':
    app.run(debug=True, port=1234)  # TODO: Modify this before uploading to the server
