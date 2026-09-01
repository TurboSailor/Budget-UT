// api.js — XMLHttpRequest wrapper talking to http://127.0.0.1:21990
.pragma library

var BASE = "http://127.0.0.1:21990";

function req(method, path, body, cb) {
    var xhr = new XMLHttpRequest();
    var url = BASE + path;
    xhr.open(method, url, true);
    xhr.setRequestHeader("Accept", "application/json");
    if (body !== null && body !== undefined) {
        xhr.setRequestHeader("Content-Type", "application/json");
    }
    xhr.timeout = 10000;
    xhr.onreadystatechange = function() {
        if (xhr.readyState === XMLHttpRequest.DONE) {
            if (xhr.status >= 200 && xhr.status < 300) {
                var data = null;
                try {
                    data = xhr.responseText ? JSON.parse(xhr.responseText) : null;
                } catch (e) {
                    cb("JSON parse error: " + e, null);
                    return;
                }
                cb(null, data);
            } else {
                var errMsg = "HTTP " + xhr.status;
                try {
                    var errObj = JSON.parse(xhr.responseText);
                    if (errObj && errObj.error) errMsg = errObj.error;
                } catch (_) {}
                cb(errMsg, null);
            }
        }
    };
    xhr.ontimeout = function() { cb("Timeout connecting to budgetd", null); };
    xhr.onerror = function() { cb("Network error connecting to budgetd", null); };
    if (body !== null && body !== undefined) {
        xhr.send(typeof body === "string" ? body : JSON.stringify(body));
    } else {
        xhr.send();
    }
}

function get(path, cb) { req("GET", path, null, cb); }
function post(path, body, cb) { req("POST", path, body, cb); }
function put(path, body, cb) { req("PUT", path, body, cb); }
function del(path, cb) { req("DELETE", path, null, cb); }
