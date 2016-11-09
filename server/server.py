#!/usr/bin/python3.5

import argparse
import logging
import random
import string
import asyncio
import base64
import time
import datetime
import uuid
import jinja2
import json
import urllib.parse
from aiohttp import web
import aiohttp_jinja2

from pythemis import ssession
from pythemis import skeygen

class Transport(ssession.mem_transport):
    def get_pub_key_by_id(self, user_id):
        print(user_id)
        return base64.b64decode(urllib.parse.unquote(pub_keys[user_id.decode("utf-8")]['pub_key']))


@asyncio.coroutine
@aiohttp_jinja2.template('index.html')
def index(request):
    url = '{scheme}://{host}/'.format(scheme="http", host=request.host)
    return {'url': url, 'server_id': 'server', 'server_public_key': urllib.parse.quote(base64.b64encode(server_public_key).decode("UTF-8"))}

@asyncio.coroutine
def get_new_messages(request):
    global history
#    if len(history) = 0:
#        text = "{\"error\" : \"<img src='https://mokum.place/system/attachments/000/178/129/mokum-medium-4965ce7a2f478e4f4a6ca07cd76b759300d17a9c.jpg'>\"}"
#    else:
#       print(123)
    text = "{\"info\": "+json.dumps(history) + "}"
    history = []
    return web.Response(text=text)    

@asyncio.coroutine
def register_new_user(request):
    data = yield from request.post()
    if(data['client_name'] in pub_keys):
        return web.Response(status=500, text="User with name <b>"+data['client_name']+"</b> already exist")
    else:
        print(data['client_name'], data['public_key'])
        pub_keys[data['client_name']] = {'pub_key': data['public_key'], 'time': time.time()}
        return web.Response(text="User <b>"+data['client_name']+"</b> registered successfully")

@asyncio.coroutine
def message(request):
    global sessions
    global history
    data = yield from request.post()
    try:
        if 'message' not in data:
            return web.Response(status=500, text="incorrect request")
        if 'session_id' not in request.cookies:
            session = ssession.ssession(b'server', server_private_key, Transport());
            msg = session.unwrap(base64.b64decode(urllib.parse.unquote(data['message'])))
            if msg.is_control:
                session_id = str(uuid.uuid4())
                sessions[session_id] = {'start': time.time(), 'last': time.time(), 'session': session}
                resp = web.Response(text=urllib.parse.quote(base64.b64encode(msg).decode("UTF-8")));
                resp.set_cookie("session_id", session_id)
                return resp
        else:
            session_id = request.cookies['session_id']
            session = sessions[session_id]['session']
            msg = session.unwrap(base64.b64decode(urllib.parse.unquote(data['message'])))
            print("mm", msg)        
            if msg.is_control:
                sessions[session_id]['last'] = time.time()
                resp = web.Response(text=urllib.parse.quote(base64.b64encode(msg).decode("UTF-8")));
                resp.set_cookie("session_id", session_id)
                return resp
            else:
                m = json.loads(msg.decode("UTF-8"))
                history.append({'name': m['name'], 'time': datetime.datetime.fromtimestamp(time.time()).strftime('%Y-%m-%d %H:%M:%S'), 'message': m['msg']})
                return web.Response(text="Ok")
    except Exception:
        return web.Response(status=500, text="Fail")

                           

@asyncio.coroutine
def init(port, loop):
    app = web.Application(loop=loop)
    app.router.add_route('GET', '/', index)
    app.router.add_route('GET', '/get_new_messages', get_new_messages)
    app.router.add_route('POST', '/connect_request', register_new_user)
    app.router.add_route('POST', '/message', message)


    aiohttp_jinja2.setup(app, loader=jinja2.FileSystemLoader('templates/'))

    handler = app.make_handler()
    srv = yield from loop.create_server(handler, '0.0.0.0', port)
    logger.info("Server started at http://0.0.0.0:{}".format(port))
    return handler, app, srv


@asyncio.coroutine
def finish(app, srv, handler):
    global online
    for sockets in online.values():
        for socket in sockets:
            socket.close()

    yield from asyncio.sleep(0.1)
    srv.close()
    yield from handler.finish_connections()
    yield from srv.wait_closed()



if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        description='Run server')

    parser.add_argument('-p', '--port', type=int, help='Port number', default=8181)
    parser.add_argument('-v', '--verbose', action='store_true', help='Output verbosity')
    args = parser.parse_args()
    port = args.port

    logging.basicConfig(level=logging.INFO if args.verbose else logging.WARNING)
    logger = logging.getLogger(__name__)

    key_pair=skeygen.themis_gen_key_pair('EC')
    server_private_key=key_pair.export_private_key()
    server_public_key=key_pair.export_public_key()
    
    pub_keys = {}
    sessions = {}
    history = []
    loop = asyncio.get_event_loop()
    handler, app, srv = loop.run_until_complete(init(port, loop))
    try:
        loop.run_forever()
    except KeyboardInterrupt:
        loop.run_until_complete(finish(app, srv, handler))
