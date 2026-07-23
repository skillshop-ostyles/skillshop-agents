const express = require('express');
const usersRouter = require('./api/users');
const ordersRouter = require('./api/orders');

const app = express();

app.use(express.json());
app.use('/api/users', usersRouter);
app.use('/api/orders', ordersRouter);

app.get('/health', (req, res) => res.json({ status: 'ok' }));

module.exports = app;
