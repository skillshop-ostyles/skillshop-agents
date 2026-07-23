const express = require('express');
const router = express.Router();
const db = require('../lib/db');
const { validateOrder } = require('../lib/validation');

router.post('/', (req, res) => {
  const errors = validateOrder(req.body);
  if (errors.length > 0) return res.status(400).json({ errors });
  const order = db.orders.create(req.body);
  res.status(201).json(order);
});

router.get('/:id/status', (req, res) => {
  const status = db.orders.getStatus(req.params.id);
  res.json({ id: req.params.id, status });
});

module.exports = router;
