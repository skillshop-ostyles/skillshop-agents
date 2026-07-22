import os

def read_config(path):
    content = open(path, 'r').read()
    return content

def write_log(data):
    f = open('/var/log/app.log', 'a')
    f.write(data)
    f.close()
