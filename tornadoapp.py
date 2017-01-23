import tornado.ioloop
import tornado.web
import json
import cerbas
from datetime import datetime


def cerbas_port():
    prod, local = False, True
    cerbas.start(prod, local)
    source = "cerbastest"
    req = json.loads(cerbas.request(func="proxiedhostport", user="foo",
        source=source, arguments=dict(server="tornado")))
    return req.get("data", 0)


def cerbas_sum(a, b):
    prod, local = False, True
    cerbas.start(prod, local)
    source = "cerbastest"
    req = json.loads(cerbas.request(func="sum", user="foo",
        source=source, arguments=dict(a=a, b=b)))
    return req.get("data", 0)


def params(content):
    return {k: content.get(k)[-1] for k in content}


class Foo(tornado.web.RequestHandler):
    def get(self):
        p = params(self.request.arguments)
        a = int(p.get("a", 0))
        b = int(p.get("b", 0))
        r = ""
        if a and b:
            r = "--> sum is {}".format(cerbas_sum(a, b))
        self.write("tornado at {} {}".format(datetime.now().isoformat(), r))

if __name__ == "__main__":
    port = cerbas_port()
    if cerbas_port:
        print("Starting Tornado App at port {}".format(port))
        application = tornado.web.Application([(r"/api7/foo", Foo)])
        application.listen(port)
        tornado.ioloop.IOLoop.current().start()
    else:
        print("port not available")

