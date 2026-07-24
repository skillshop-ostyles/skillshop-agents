const fs = require('fs');
const http = require('http');
const { createPool } = require('mysql2');

const pool = createPool({
  host: 'localhost',
  user: 'root',
  database: 'myapp',
  connectionLimit: 10
});

function readConfig(path) {
  return fs.readFileSync(path, 'utf8');
}

function processFile(path) {
  const fd = fs.openSync(path, 'r');
  const data = fs.readFileSync(fd, 'utf8');
  // Missing fs.closeSync(fd) - LEAK
  return data;
}

function fetchUrl(url) {
  return new Promise((resolve, reject) => {
    http.get(url, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => resolve(data));
    }).on('error', reject);
  }); // Socket auto-closes on end - SAFE
}

function queryDb(sql) {
  return new Promise((resolve, reject) => {
    pool.query(sql, (err, results) => {
      if (err) reject(err);
      else resolve(results);
    });
  }); // Pool handles release - SAFE
}

function writeLog(filepath, message) {
  const stream = fs.createWriteStream(filepath, { flags: 'a' });
  stream.write(message + '\n');
  // Missing stream.end() - LEAK
  return stream;
}

function safeTemp() {
  const tmp = fs.openSync('/tmp/test.tmp', 'w');
  try {
    fs.writeSync(tmp, 'test data');
    return true;
  } finally {
    fs.closeSync(tmp);
  } // SAFE (finally block)
}

function onRequest(req, res) {
  // Missing res.on('close') cleanup
  const timer = setInterval(() => {
    res.write('keepalive\n');
  }, 1000);
  // Leak if client disconnects - POTENTIAL LEAK
}

const server = http.createServer(onRequest);
server.listen(3000);
