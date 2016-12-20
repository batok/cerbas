import cerbas
import json


def test():
    prod, local = False, True
    cerbas.start(prod, local)
    source = "cerbastest"
    args = dict()
    print json.loads(cerbas.request(func="hello", user="foo", source=source))
    print json.loads(cerbas.request(func="slow", user="foo", source=source))
    print json.loads(cerbas.request(func="halt", user="foo", source=source, arguments=dict(delay=1000)))

if __name__ == "__main__":
    test()
