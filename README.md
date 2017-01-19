
# CERBAS (=C=oncurrent =E=lixir/Erlang =R=edis-backed =A=PI =S=erver).
___________________________________________________________________

It’s a server engine written in erlang ecosystem’s elixir language. 

CERBAS concurrently handles requests made by clients using redis 
( data structure in-memory key value store ).

CERBAS reads requests from redis stored like json structures and 
dispatch them to elixir functions.  The returned values from those functions
are delivered to clients by means of redis’ publish subscribe mechanism. 

CERBAS is also a cron like facility to dispatch functions instead of scripts.
( See CRONTAB file )

CERBAS includes a Plug module where you can test your functions or customize to your needs.  

Also the Plug module serves as a proxy to other webservers.

Client - Server interaction using CERBAS.

1 - Client prepares a request which is json data containing:  

```
{“func”: “name of an alias to a real function”, “args”:
json_object_containg_arguments_if_any, “user”: “registered user name”, “source”: “kind of program where the request is generated, i.e. ror which is also registered”}
```

Example 1:

```
{“func”: “s3backup”, “args”: {}, “user”: “tom”, “source”: “flask_app”}
```

Example 2 ( with parameters ):

```
{“func”: “tablecount”, “args”: {“table”: “users”, “database”, “awesomedb”}, “user”: “peter”, “source”: “ror” }  
```

Example 3 ( with delay in milliseconds before running the task or function ):

```
{“func”: “send_a_notification_in_a_minute”, “args”: {}, “user”: “alice”, source:”django_app”, delay= 60000} 
```

2 - Steps done by any client in any language connected to redis ( db = 1 [dev], db = 8 [prod]).

A - INCR CERBAS_COUNTER

B - GET CERBAS_COUNTER

C - Key name is built this way:

CERBAS-REQ-[Value of CERBAS_COUNTER zero filled right justified to ten digits]

Example:

CERBAS-REQ-0000000001

D - SET Key as in "C" with the value of serialized json request ( see previous examples ). 

E - RPUSH CERBAS_QUEUE [ with CERBAS_COUNTER contents, i.e. 1 ]

F - If the request doesn’t expect an answer from CERBAS that was it.

G - Redis pub-sub channel name built this way:

CERBAS-RESPONSE-[Value of number of redis db (1,8)]-[Value of CERBAS_COUNTER
zero filled right justified to ten digits]    

Example:

CERBAS-RESPONSE-1-0000000001


H - Client subscribe to this channel waiting for a response from CERBAS ( Server will publish the response to this channel when finishes processing the request ).


I - Response has the following json structure

{“status”: “ok”, “data”: json_value_or_structure_containing_result}   when ok
{“status”: “error”, “data”: “error message” } when having errors.

What CERBAS server does is reading values from the queue (LPOP) , (GET) ing the value of the key formed with the popped value, deleting the original request ( DELETE) and routing the request to a real elixir function which must return the possible values:

json value can be any poison serializable content

```elixir
{:error, “error message”}
````

CERBAS will intercept this value an build the appropriate json response that will publish using the right channel in two forms:  raw and compressed via msgpack.  If the content was msgpacked the channel name used will be prefixed by MSGPACK:.

Due to concurrent goodies of the erlang vm every request is dispatched in its own process without conflicting or waiting for previous requests.

ADVANTAGES of this architecture.

1 - A request is easy to do from any programming language with a redis library ( with subscribe capabilities ).

2 - Requests are language agnostic ( they are only json values serialized to strings ). Responses ( if any ) are also language agnostic ( they are only json values serialized to strings and optionally compressed as msgpack ). Note: if the client need msgpack compression, the client interface needs a msgpack library.

This is the elixir function that return the lua script that will be used by the server.

```elixir
 defp lua_script_redis() , do: """
  local channel = KEYS[1];
  local msgpack_channel = "msgpack:" .. channel;
  local value = ARGV[1];
  redis.call('PUBLISH', channel, value);
  local mvalue = cmsgpack.pack(cjson.decode(value));
  return redis.call('PUBLISH', msgpack_channel, mvalue);
  """
```
( Server make responses via publishing to channels using lua-scripting, sending both compressed and non-compressed data )

4 - Requests can be made from web applications and client-server desktop applications.

Example of client code using python (cerbas.py):

```python
import redis, sys, json, argparse
import cPickle as pickle
from datetime import datetime
import umsgpack as mp
PREFIX = "CERBAS"
r = None
def start(prod=False, local=False):
    global r
    global db
    host = "10.0.1.124"
    if local:
        host = "127.0.0.1"

    db = 1

    if prod:
        db = 8
    r = redis.Redis(host = host, port = 6379, db = db )

def request(func = "dummy", source = "test", user = "test", arguments = None, msgpack = False):
    PREFIX = "CERBAS"
    k = r.incr("{}-COUNTER".format(PREFIX))
    nk = "{}-REQ-{:010d}".format(PREFIX, k)
    rk = "{}-RESPONSE-{}-{:010d}".format(PREFIX, get_database_number(), k)
    d = dict(func = func, source = source, user = user)
    if arguments and isinstance( arguments, dict):
            d["args"] = arguments
    if msgpack:
        rk = "MSGPACK:{}".format(rk)


    msg = json.dumps( d )
    r.set(nk, msg)
    r.rpush("{}-QUEUE".format(PREFIX),k)
    ps = r.pubsub()
    ps.subscribe(rk)


    result = ""
    for x in ps.listen():
            if x and x.get("type") == "message":
                    result = x.get("data")
                    ps.unsubscribe(x.get("channel"))


    if msgpack:
        result = json.dumps(mp.unpackb(result))
    return result
```

(cerbastest.py)

```python
import cerbas
import json


def request(func, user, source, arguments = None):
    if arguments:
        v = json.loads(cerbas.request(func=func, user=user, source=source, arguments=arguments))
    else:
        v = json.loads(cerbas.request(func=func, user=user, source=source))
    return v

def test():
    prod, local = False, True
    cerbas.start(prod, local)
    source = "cerbastest"
    print( request(func="hello", user="foo", source=source, msgpack=True))
    print( request(func="hello", user="foo", source=source))
    print( request(func="slow", user="foo", source=source))
    print( request(func="halt", user="foo", source=source, arguments=dict(delay=1000)))

if __name__ == "__main__":
    test()
```

Example of client code using elixir:

```elixir
def process_request(func \\ "dummy", source \\ "test", user \\ "test", args \\ nil, one_way \\ false) do
    {:ok, client_sub} = Exredis.Sub.start_link
    {:ok, svalue} = command(["INCR", "CERBAS-COUNTER"])
    nk = "CERBAS-REQ-#{zformat(svalue,10)}"
    rk = "CERBAS-RESPONSE-#{zformat(svalue,10)}"

    unless is_map(args) do
      args = nil
    end

    d = Poison.encode!(%Request{func: func, args: args, source: source, user: user})
    command(["SET", nk, d])
    command(["RPUSH","CERBAS-QUEUE", svalue])

    if one_way do
      nil
    else
      subscribe(client_sub, rk)
      |> decode_response
    end
end
```


CERBAS also includes a mechanism for dispatching functions 
by means of a CRON compatible file ( see CRONTAB included ).  
Unlike a normal cron dispatcher CERBAS dispatches functions 
running at the server instead of scripts or programs.

CERBAS includes also a Plug process which can be used for any purposes or as a
proxy ( WIP ) to other web servers like RoR, Django, Flask, Pyramid, Tornado,
Express.

To run CERBAS you need redis.  One way to install redis from mac os is to clone it from
github with hub [brew install hub]:

```
$ hub clone antirez/redis
$ cd redis
$ make
```

then run it:

```
$ src/redis-server
```

To run the cerbastest.py example you need python 2.7 or + with redis and
msgpack-python installed with pip ( pip install msgpack-python redis ).
 
( I recommend using virtualenv for python 2.7 or venv for python 3)

CERBAS uses elixir's registry to handle elixir’s agents needed to work, therefore needs
at least elixir 1.4-rc .  I have run CERBAS with master version (1.5-dev)
and erlang 19.2 installed with kerl without a hitch.

You also need erlang installed (v 18+).

To install erlang 19.2 with kerl in macos sierra

First install kerl...

```
$ mkdir kerl_zone
$ cd kerl_zone
$ curl -O https://raw.githubusercontent.com/kerl/kerl/master/kerl
$ chmod a+x kerl
```

Then 

```
$ ./kerl update releases
$ KERL_CONFIGURE_OPTIONS="--with-ssl=/usr/local/opt/openssl" ./kerl build 19.2
19.2

$ ./kerl install 19.2 19.2

$ . 19.2/activate
```

To run Cerbas:

Clone this repo, cd to cerbas and 

```
$ mix deps.get

$ mix run
```

Once running you can try the `cerbastest.py` or go to `http://localhost:4455/api/hello`


Python 2.7 or Python 3.6 can be used to run cerbastest.py

If using Python 3 install libraries in a virtual env

$ python3 -m venv mypath
$ pip install redis u-msgpack-python

and run it ...

$ python3 cerbastest.py


The python client code will stop CERBAS calling the `halt` function via redis.

There's a `tornadoapp.py` (python) which runs a tornado based wsgi app which gets its
port from calling the CERBAS api.  If you point your browser to
`http://localhost:4455/api7/foo?a=23&b=54`  you get a response with the sum of a
and b ( the app uses the CERBAS api to get the result, in this case 77 ).  

To run the tornado
app you need a python environment with tornado and redis libraries installed ( via pip install
tornado redis u-msgpack-python). After that just

```
$ python tornadoapp.py
```

The tornado app must be started after CERBAS, because gets its port from
CERBAS.

There's also an express app.  You can run it with npm i and node
espressapp.js.  Point your browser to http://localhost:4455/api6/foo and you
get the response from node via the CERBAS prox

There's also an express app.  

You can run it with: 

```
$ npm i 
```

and

```
$ node expressapp.js
```

Point your browser to http://localhost:4455/api6/foo and you
get the response from express via the CERBAS proxy.

The cron manager will run hello function every minute according to CRONTAB
file included.

You can stop CERBAS with ctrl-c

CERBAS is just a starting point for your API Server needs, so feel free to customize it.

IMPORTANT NOTE:  CERBAS is changing every day.

Any questions: at slack elixir's team and/or via twitter : @batok
