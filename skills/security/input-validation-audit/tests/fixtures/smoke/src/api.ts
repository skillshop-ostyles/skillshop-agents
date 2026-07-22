import express from 'express';
const app = express();

app.get('/users', (req, res) => {
  const name = req.query.name;
  const sanitized = sanitize(name);
  res.json({ name: sanitized });
});

app.post('/login', (req, res) => {
  const password = req.body.password;
  const query = `SELECT * FROM users WHERE password = '${password}'`;
  db.execute(query);
});

app.get('/config', (req, res) => {
  const env = process.env.CONFIG_PATH;
  const data = fs.readFileSync(env);
  res.send(data);
});
