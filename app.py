#!flask/bin/python
from flask import Flask, jsonify
from database_connection import run_select_for_json, execute_command

app = Flask(__name__)


@app.route('/')
def index():
    return jsonify(hello="Hello, World!")


@app.route('/get_user/<username>', methods=['GET'])
def get_user(username):
    return run_select_for_json(
        f'select username, pin, ut.user_type from "user" as u join user_types ut on u.user_type_fk = ut.pk where username = \'{username}\';')


@app.route('/get_tank_info/<username>', methods=['GET'])
def get_tank_info(username):
    return run_select_for_json(
        f'select username, pin, tr.current_height, to_char(tr.timestamp, \'DD Mon YYYY HH:MI:SSPM\') as timestamp from "user" as u join tank_readings tr on u.pk = tr.tank_owner_fk where username = \'{username}\' order by tr.timestamp desc limit 1;')


@app.route('/get_work_list/', methods=['GET'])
def get_work_list():
    return run_select_for_json(
        f'select mw.pk, to_char(mw.timestamp, \'DD Mon YYYY HH:MI:SSPM\') as timestamp, u.username, u.house_number, tt.tank_type, te.estimate from manager_worklist as mw join "user" u on mw.resident_fk = u.pk join tank_types tt on u.tank_type_fk = tt.pk join time_estimates te on mw.time_estimate_fk = te.pk')


@app.route('/add_user/<user_name>/<user_type>/<user_pin>')
def add_user(user_name, user_type, user_pin):
    execute_command(
        f"insert into \"user\" (username, user_type_fk, pin) values ('{user_name}', {user_type}, '{user_pin}')")
    return run_select_for_json('select * from "user";')


@app.route('/add_resident/<user_name>/<house_number>/<user_pin>')
def add_resident(user_name, house_number, user_pin):
    execute_command(
        f"insert into \"user\" (username, user_type_fk, house_number, pin) values ('{user_name}', 1, {house_number}, '{user_pin}')")
    return run_select_for_json('select * from "user";')


@app.route('/app_login/', methods=['GET'])
def get_app_login():
    return run_select_for_json("SELECT * FROM app_login")


@app.route('/remove_user/<user_name>')
def remove_user(user_name):
    execute_command(f'delete from "user" where username = \'{user_name}\'')
    return run_select_for_json('select * from "user";')


if __name__ == '__main__':
    app.run(debug=True)
