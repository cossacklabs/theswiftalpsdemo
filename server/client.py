#!/usr/bin/python3.5
import http.client, urllib.parse, http.cookies
import urllib.parse
import base64
import json
import random
import string
import argparse


from pythemis import ssession
from pythemis import skeygen

parser = argparse.ArgumentParser()
parser.add_argument('-u', '--url', help='ip', default="127.0.0.1")
parser.add_argument('-p', '--port', help='port', type=int, default=8181)
parser.add_argument('-s', '--server_pub_key', help='server public key')
args = parser.parse_args()
port = args.port

url = args.url
port = args.port
server_id = 'server'
server_pub_key = args.server_pub_key
messages = ["message1", "message2", "message3", "message4", "message5", "message6", "message7", "message8", "message9", "message10"]

id_symbols = string.ascii_letters + string.digits + ' '
def generate_str(len):
    return ''.join([random.choice(id_symbols) for _ in range(len)])

client_name = generate_str(10)
for i in range(0,99):
    messages.append(generate_str(48))

key_pair=skeygen.themis_gen_key_pair('EC')
client_private_key=key_pair.export_private_key()
client_public_key=key_pair.export_public_key()

class Transport(ssession.mem_transport):
    def get_pub_key_by_id(self, user_id):
        if user_id == b'server':
            return base64.b64decode(urllib.parse.unquote(server_pub_key))


params = urllib.parse.urlencode({'client_name': client_name, 'public_key': base64.b64encode(client_public_key)})
headers = {"Content-type": "application/x-www-form-urlencoded", "Accept": "text/plain"}
conn = http.client.HTTPConnection(url, port)
conn.request("POST", "/connect_request", params, headers)
response = conn.getresponse()
if response.status == 200:
    print(response.read())
    print(response.getheaders())
    
    session = ssession.ssession(client_name.encode("UTF-8"), client_private_key, Transport())
    msg = session.connect_request()
    while True:
        params = urllib.parse.urlencode({'client_name': client_name,'message': base64.b64encode(msg)})
        conn.request("POST", "/message", params, headers)
        response = conn.getresponse()
        msg = response.read()    
        if response.status == 200:
            print(msg)
            print(response.getheaders())
            cookie = http.cookies.SimpleCookie()
            headers["Cookie"] = ""
            for header in response.getheaders():
                if header[0] == 'Set-Cookie':
                    cookie.load(header[1])
                    headers["Cookie"] = "session_id="+cookie['session_id'].value
            msg = session.unwrap(base64.b64decode(urllib.parse.unquote(msg.decode("utf-8"))))
            print(msg)
            if not msg.is_control:
                break

    for mess in messages:
        m = {'name': client_name, 'msg': mess}
        params = urllib.parse.urlencode({'client_name': client_name,'message': base64.b64encode(session.wrap(mess.encode("UTF-8")))})
        conn.request("POST", "/message", params, headers)
        response = conn.getresponse()
        if response.status != 200:
            break;
        print(response.read())

conn.close()
