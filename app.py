from flask import Flask
import cerbas
import json
from datetime import datetime
app = Flask(__name__)


def cerbas_port():
    prod, local = False, True
    cerbas.start(prod, local)
    source = "cerbastest"
    req = json.loads(cerbas.request(func="proxiedhostport", user="foo",
        source=source, arguments=dict(server="flask")))
    return req.get("data", 0)

@app.route("/api5/foo")
def hello():
    return "foo from flask at {}".format(datetime.now().isoformat())

if __name__ == "__main__":
    port = cerbas_port()
    if port:
        app.run(host=None, port=port)
    else:
        print("port not available")
