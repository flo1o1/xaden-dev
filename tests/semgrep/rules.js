// REQ-014, REQ-040, REQ-143: fixtures for template/.semgrep/rules.yml (semgrep --test in check-scaffold.sh).
const cp = require("child_process");
const crypto = require("crypto");
const libxmljs = require("libxmljs");
const jwt = require("jsonwebtoken");
const fs = require("fs");
const path = require("path");

function fixtures(element, userInput) {
  // ruleid: js-eval
  eval(userInput);
  // ruleid: js-innerhtml-dynamic
  element.innerHTML = userInput;
  // ok: js-innerhtml-dynamic
  element.innerHTML = "<b>static</b>";
  // ruleid: js-tls-verification-disabled
  const options = { host: "example.invalid", rejectUnauthorized: false };
  // ruleid: js-child-process-string-command
  cp.exec(`ls ${userInput}`);
  // ok: js-child-process-string-command
  cp.execFile("ls", [userInput]);
  return options;
}

function redirectFixtures(req, res) {
  const target = req.query.next;
  // ruleid: js-open-redirect
  res.redirect(target);
  // ruleid: js-open-redirect
  res.redirect(302, req.body.returnTo);
  // ok: js-open-redirect
  res.redirect("/home");
}

function regexFixtures(req, text) {
  // ruleid: js-regex-from-input
  const search = new RegExp(req.query.q);
  // ok: js-regex-from-input
  const fixed = new RegExp("^[a-z]+$");
  return search.test(text) && fixed.test(text);
}

function createResetToken() {
  // ruleid: js-insecure-random-secret
  return Math.random().toString(36).slice(2);
}

function randomFixtures() {
  // ruleid: js-insecure-random-secret
  const sessionId = Math.random().toString(16);
  // ok: js-insecure-random-secret
  const jitter = Math.random() * 100;
  // ok: js-insecure-random-secret
  const apiKey = crypto.randomBytes(32).toString("hex");
  return [sessionId, jitter, apiKey];
}

function hashFixtures(password, data) {
  // ruleid: js-weak-password-hash
  const digest = crypto.createHash("sha256").update(password).digest("hex");
  // ok: js-weak-password-hash
  const checksum = crypto.createHash("sha256").update(data).digest("hex");
  return [digest, checksum];
}

function cookieFixtures(res, token) {
  // ruleid: js-cookie-without-flags
  res.cookie("session", token);
  // ruleid: js-cookie-without-flags
  res.cookie("session", token, { secure: true });
  // ok: js-cookie-without-flags
  res.cookie("session", token, { secure: true, httpOnly: true, sameSite: "lax" });
  // ok: js-cookie-without-flags
  res.cookie("session", token, { httpOnly: true, sameSite: "strict", secure: true });
}

function xmlFixtures(document) {
  // ruleid: js-xml-external-entities
  libxmljs.parseXml(document, { noent: true });
  // ok: js-xml-external-entities
  return libxmljs.parseXml(document);
}

function classFixtures(req, res, token, key, serialize, vm) {
  // ruleid: js-jwt-none
  jwt.verify(token, key, { algorithms: ["none"] });
  // ok: js-jwt-none
  jwt.verify(token, key, { algorithms: ["HS256"] });
  // ruleid: js-cors-wildcard
  cors({ origin: "*" });
  // ruleid: js-cors-wildcard
  res.setHeader("Access-Control-Allow-Origin", "*");
  // ok: js-cors-wildcard
  cors({ origin: "https://example.invalid" });
  // ruleid: js-unsafe-deserialization
  serialize.unserialize(req.body.data);
  // ruleid: js-unsafe-deserialization
  vm.runInNewContext(req.body.code);
  // ok: js-unsafe-deserialization
  JSON.parse(req.body.data);
}

function ssrfFixtures(req) {
  const target = req.query.url;
  // ruleid: js-ssrf-from-request
  fetch(target);
  // ruleid: js-ssrf-from-request
  axios.get(req.body.url);
  // ok: js-ssrf-from-request
  return fetch("https://api.example.invalid/items");
}

function pathFixtures(req, res) {
  const name = req.query.file;
  // ruleid: js-path-from-request
  fs.readFileSync(name);
  // ruleid: js-path-from-request
  res.sendFile(req.params.path);
  // ok: js-path-from-request
  fs.readFileSync(path.basename(name));
  // ok: js-path-from-request
  return fs.readFileSync("/srv/static/index.html");
}

module.exports = {
  classFixtures,
  ssrfFixtures,
  pathFixtures,
  fixtures,
  redirectFixtures,
  regexFixtures,
  createResetToken,
  randomFixtures,
  hashFixtures,
  cookieFixtures,
  xmlFixtures,
};
