# CERBAS

Cerbas let languages other than elixir call functions written in elixir. 

Cerbas uses redis as the "broker".  

A client code, for example in python, prepares a json compatible request which stores in redis.  

The json is fetched by cerbas server and routed to the configured elixir function.  

The returned value from the function is serialized to a json response that is dispatched to the client by means of redis' publish capability.


>Client -> json-request -> cerbas driver -> redis -> listen in channel X

>Cerbas Server read incoming requests and dispatches to configured elixir functions, publish result to channel X.


To run cerbas install and ...

run redis...
```
$ redis-server
```

Open other terminal window and install
elixir 1.4 

and ...

clone this repo

```
$ git clone https://github.com/batok/cerbas.git
```

```
$ cd cerbas
$ mix deps.get
$ mix run
```


Open other terminal window and install python's stuff...

```
$ cd cerbas
$ python3 -m venv py3env
$ source py3env/bin/activate
$ pip install -r requirements.txt
```

and run the python example...

```
$ python3 cerbastest.py 
```

cerbastest.py make some requests to redis, which are routed to elixir functions by CERBAS Server.

the last request "halt" will stop CERBAS Server.

==================================================================

Cerbas can: 

* handle a timeout for executing functions ( default to 5 seconds).  

* compress published responses with msgpack ( optional ).

* cache values for specific functions.

* run scheduled functions by means of a CRON compatible file.


Use cases:

* Scripts or code from any language which at some point need call one or more functions developed with elixir/erlang.

* CRON like execution of elixir functions


Plus:

Cerbas includes a Plug Web Server which also serve as proxy to other web apps.  Four examples are included.

To run the tornado app ...

```
$ python3 tornadoapp.py
```

Open any browser and go to localhost:4455/api7/foo

Cerbas' plug server will receive the http request and will route it to tornado web app.  

===

The language must communicate with redis and serialize to and from a json like structure.  Both are pretty supported in any language.  The only caveat is that the redis communication  must support "subscribe".

Currently only a python driver for cerbas is included but write an specific driver for any other language is easy if follow these:

Client - Server interaction using CERBAS.

1 - Client prepares a request which is json data containing:  

```
{“func”: “name of an alias name to a real function”, “args”:
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

CERBAS-RESPONSE-[Value of number of redis db (1 for dev or 8 for production)]-[Value of CERBAS_COUNTER
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



