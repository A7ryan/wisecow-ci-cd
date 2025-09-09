import tornado.web
import requests
from healthcheck import TornadoHandler, HealthCheck, EnvironmentDump

website_url = "https://aws.amazon.com/"
website_name = website_url.split("//")[-1].split("/")[0]

def check_website_uptime():
    resp = requests.get(website_url, timeout=5)
    if resp.status_code == 200:
        return True, website_name + " is reachable"
    else:
        return False, website_name + f" returned {resp.status_code}"
    

health = HealthCheck(checkers=[check_website_uptime])

def application_data():
    return {"maintainer": "Aryan",
            "git_owner": "https://github.com/a7ryan"}

envdump = EnvironmentDump(application=application_data)

app = tornado.web.Application([
    ("/healthcheck", TornadoHandler, dict(checker=health)),
    ("/environment", TornadoHandler, dict(checker=envdump)),
])


if __name__ == "__main__":
    app.listen(5000)
    tornado.ioloop.IOLoop.current().start()
