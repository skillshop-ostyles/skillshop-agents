import express from 'express';
import mongoose from 'mongoose';
import cron from 'node-cron';
import * as heavyMlLib from 'heavy-ml-library';

const app = express();
app.use(express.json());

mongoose.connect('mongodb://localhost/myapp', {
  poolSize: 10,
  serverSelectionTimeoutMS: 5000
});

const userCache = new Map<string, any>();

cron.schedule('*/5 * * * *', () => {
  console.log('Running admin cleanup task');
});

app.get('/analyze', (req, res) => {
  const result = heavyMlLib.analyze(req.query.text);
  res.json(result);
});

app.get('/users/:id', (req, res) => {
  res.json({ id: req.params.id });
});

app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

app.listen(3000, () => {
  console.log('Server started on port 3000');
});
