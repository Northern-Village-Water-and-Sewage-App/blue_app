FROM python:3.6

#RUN apt-get update -y && \
#    apt-get install -y python3-pip python3-dev

# We copy just the requirements.txt first to leverage Docker cache

WORKDIR /app

#RUN python3 -m pip install -r requirements.txt

RUN pip3 install psycopg2 pandas flask

COPY . /app

ENTRYPOINT [ "python" ]

CMD [ "app.py" ]
