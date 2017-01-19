import cerbas
import json


def request(func, user, source, arguments=None, msgpack=False):
    if arguments:
        v = json.loads(cerbas.request(func=func, user=user, source=source, arguments=arguments, msgpack=msgpack))
    else:
        v = json.loads(cerbas.request(func=func, user=user, source=source, msgpack=msgpack))
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
