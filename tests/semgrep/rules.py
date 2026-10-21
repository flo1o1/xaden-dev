# REQ-014, REQ-040, REQ-143: fixtures for template/.semgrep/rules.yml (semgrep --test in check-scaffold.sh).
import hashlib
import os
import pickle
import random
import re
import secrets
import subprocess
import urllib.request
import xml.etree.ElementTree as ET

import defusedxml.ElementTree
import jwt
import requests
import yaml
from flask import redirect, request, send_file
from flask_cors import CORS
from werkzeug.utils import secure_filename
from lxml import etree


def fixtures(cursor, user_input, app):
    # ruleid: python-subprocess-shell-true
    subprocess.run(user_input, shell=True)
    # ok: python-subprocess-shell-true
    subprocess.run(["ls", user_input])
    # ruleid: python-eval-exec
    eval(user_input)
    # ruleid: python-unsafe-deserialization
    pickle.loads(user_input)
    # ruleid: python-yaml-unsafe-load
    yaml.load(user_input)
    # ok: python-yaml-unsafe-load
    yaml.load(user_input, Loader=yaml.SafeLoader)
    # ruleid: python-sql-built-from-strings
    cursor.execute(f"SELECT * FROM users WHERE name = '{user_input}'")
    # ok: python-sql-built-from-strings
    cursor.execute("SELECT * FROM users WHERE name = %s", (user_input,))
    # ruleid: python-tls-verification-disabled
    requests.get("https://example.invalid", verify=False)
    # ruleid: python-debug-server
    app.run(debug=True)


def redirect_fixtures():
    target = request.args.get("next")
    # ruleid: python-open-redirect
    redirect(target)
    # ruleid: python-open-redirect
    redirect(request.form["next"])
    # ok: python-open-redirect
    return redirect("/home")


def regex_fixtures(text):
    term = request.args.get("q")
    # ruleid: python-regex-from-input
    re.search(term, text)
    # ruleid: python-regex-from-input
    re.compile(request.form["pattern"])
    # ok: python-regex-from-input
    re.search(re.escape(term), text)
    # ok: python-regex-from-input
    return re.match(r"^[a-z]+$", text)


def make_reset_token():
    # ruleid: python-insecure-random-secret
    return str(random.randint(100000, 999999))


def random_fixtures():
    # ruleid: python-insecure-random-secret
    api_key = random.getrandbits(128)
    # ok: python-insecure-random-secret
    delay = random.uniform(0.1, 0.5)
    # ok: python-insecure-random-secret
    session_token = secrets.token_urlsafe(32)
    return api_key, delay, session_token


def hash_fixtures(password, data):
    # ruleid: python-weak-password-hash
    digest = hashlib.sha256(password.encode()).hexdigest()
    # ruleid: python-weak-password-hash
    legacy = hashlib.md5(user_password)
    # ok: python-weak-password-hash
    checksum = hashlib.sha256(data).hexdigest()
    # ok: python-weak-password-hash
    derived = hashlib.scrypt(password.encode(), salt=b"salt", n=16384, r=8, p=1)
    return digest, legacy, checksum, derived


def cookie_fixtures(response, token):
    # ruleid: python-cookie-without-flags
    response.set_cookie("session", token)
    # ruleid: python-cookie-without-flags
    response.set_cookie("session", token, secure=True)
    # ok: python-cookie-without-flags
    response.set_cookie("session", token, secure=True, httponly=True, samesite="Lax")
    # ok: python-cookie-without-flags
    response.set_cookie("session", token, httponly=True, samesite="Strict", secure=True)


def xml_fixtures(document):
    # ruleid: python-unsafe-xml-parser
    ET.fromstring(document)
    # ruleid: python-unsafe-xml-parser
    etree.XMLParser(resolve_entities=True)
    # ok: python-unsafe-xml-parser
    return defusedxml.ElementTree.fromstring(document)


def class_fixtures(user_input, token, key, app, response):
    # ruleid: python-os-command
    os.system("ls " + user_input)
    # ruleid: python-os-command
    os.popen(user_input)
    # ok: python-os-command
    subprocess.run(["ls", user_input], check=True)
    # ruleid: python-jwt-unverified
    jwt.decode(token, options={"verify_signature": False})
    # ruleid: python-jwt-unverified
    jwt.decode(token, key, algorithms=["none"])
    # ok: python-jwt-unverified
    jwt.decode(token, key, algorithms=["HS256"])
    # ruleid: python-cors-wildcard
    CORS(app, origins="*")
    # ruleid: python-cors-wildcard
    response.headers["Access-Control-Allow-Origin"] = "*"
    # ok: python-cors-wildcard
    CORS(app, origins=["https://example.invalid"])


def ssrf_fixtures():
    target = request.args.get("url")
    # ruleid: python-ssrf-from-request
    requests.get(target)
    # ruleid: python-ssrf-from-request
    urllib.request.urlopen(request.form["url"])
    # ok: python-ssrf-from-request
    return requests.get("https://api.example.invalid/items", params={"q": target})


def path_fixtures():
    name = request.args.get("file")
    # ruleid: python-path-from-request
    open(name)
    # ruleid: python-path-from-request
    send_file(request.values["path"])
    # ok: python-path-from-request
    open(secure_filename(name))
    # ok: python-path-from-request
    return open("/srv/static/index.html")
