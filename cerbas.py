import redis, sys, json, argparse
import cPickle as pickle
from datetime import datetime
import msgpack as mp
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
    k = r.incr("{}-COUNTER".format(PREFIX))
    nk = "{}-REQUEST-{:010d}".format(PREFIX,k)
    rk = "{}-RESPONSE-{}-{:010d}".format(PREFIX,db,k)
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
        print "usando msgpack"
        result = json.dumps(mp.unpackb(result))
    return result

def request_without_response(func = "dummy", source = "test", user = "test", arguments = None, msgpack = False):
    k = r.incr("{}-COUNTER".format(PREFIX))
    nk = "{}-REQUEST-{:010d}".format(PREFIX,k)
    rk = "{}-RESPONSE-{}-{:010d}".format(PREFIX,db,k)
    d = dict(func = func, source = source, user = user)
    if arguments and isinstance( arguments, dict):
	    d["args"] = arguments
    if msgpack:
        rk = "MSGPACK:{}".format(rk)

    msg = json.dumps( d )
    r.set(nk, msg)
    r.rpush("{}-QUEUE".format(PREFIX),k)
    return

