from flask import Flask
app = Flask(__name__)

@app.route("/api5/foo")
def hello():
  return "foo from flask"

if __name__ == "__main__":
  app.run()
