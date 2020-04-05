#!flask/bin/python
from flask import Flask, jsonify
from database_connection import run_select_for_json, execute_command, get_query_result_as_df, pd

app = Flask(__name__)


@app.route('/')
def index():
    return jsonify(hello="Hello, World!")


@app.route('/update_demand/<pk>/<time_estimate_fk>')
def update_demand(pk, time_estimate_fk):
    execute_command(
        f'update manager_worklist set time_estimate_fk = {time_estimate_fk} where pk = {pk};')
    return run_select_for_json('select * from app_worklist')


@app.route('/demand_completed/<pk>')
def demand_completed(pk):
    df = get_query_result_as_df(f"select resident_fk, tank_type_fk, timestamp from manager_worklist where pk = {pk}")
    resident_fk = df['resident_fk'][0]
    tank_type_fk = df['tank_type_fk'][0]
    timestamp = df['timestamp'][0]
    print(timestamp)
    execute_command(f"insert into delivery_completed (resident_fk, tank_type_fk, time_at_worklist_added) values ({resident_fk}, {tank_type_fk}, '{timestamp}');")
    execute_command(f"delete from manager_worklist where pk = {pk}")
    return run_select_for_json("select * from app_completed_worklist")


@app.route('/get_reports/')
def get_reports():
    return run_select_for_json('select * from app_reports')


@app.route('/disable_resident/<resident_username>')
def disable_resident(resident_username):
    execute_command(
        f"update residents set resident_disabled = true where username = '{resident_username}';")
    return run_select_for_json('select * from residents;')


@app.route('/enable_resident/<resident_username>')
def enable_resident(resident_username):
    execute_command(
        f"update residents set resident_disabled = false where username = '{resident_username}';")
    return run_select_for_json('select * from residents;')


@app.route('/add_report/<complaint_type_fk>/<company_fk>/<complaint>/')
def add_report(complaint_type_fk, company_fk, complaint):
    execute_command(
        f"insert into reports (complaint_type_fk, company_fk, complaint) values ({complaint_type_fk}, {company_fk}, '{complaint}')")
    return run_select_for_json("select * from app_reports;")


@app.route('/add_message/<message>')
def add_message(message):
    execute_command(f"insert into message (messages) values ('{message}')")
    return run_select_for_json("select * from message")


@app.route('/get_latest_message/')
def get_latest_message():
    return run_select_for_json(
        "select message.messages from message order by timestamp desc limit 1")


@app.route('/get_user/<username>', methods=['GET'])
def get_user(username):
    return run_select_for_json(
        f'select * from app_login where username = \'{username}\';')


@app.route('/get_tank_info/<username>', methods=['GET'])
def get_tank_info(username):
    return run_select_for_json(f'select '
                               f'username, '
                               f'status as sewage_tank_status, '
                               f'to_char(str.timestamp, \'DD Mon YYYY HH:MI:SSPM\') as sewage_tank_timestamp, '
                               f'wtr.current_height/wtm.tank_height * 100 as water_tank_height_percentage, '
                               f'wtr.current_height as water_tank_height, '
                               f'to_char(wtr.timestamp, \'DD Mon YYYY HH:MI:SSPM\') as water_tank_timestamp '
                               f'from residents join sewage_tank_readings str on '
                               f'residents.pk = str.tank_owner_fk '
                               f'join water_tank_readings wtr on residents.pk = wtr.tank_owner_fk '
                               f'join water_tanks_models wtm on residents.water_tank_fk = wtm.pk '
                               f'where username = \'{username}\' '
                               f'order by str.timestamp, wtr.timestamp desc '
                               f'limit 1;')


@app.route('/get_work_list/', methods=['GET'])
def get_work_list():
    return run_select_for_json('select * from app_worklist')


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
    app.run(debug=True, host='0.0.0.0',
            port=32132)  # TODO: Modify this before uploading to the server
