#!flask/bin/python
from flask import Flask
from database_connection import run_select_for_json

app = Flask(__name__)


@app.route('/')
def index():
    return "Hello, World!"


@app.route('/app_login/', methods=['GET'])
def get_app_login():
    return run_select_for_json("SELECT * FROM app_login")


if __name__ == '__main__':
    app.run(debug=True)
