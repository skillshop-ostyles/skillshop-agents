const express = require('express');
const router = express.Router();
const db = require('../lib/db');

router.get('/:id', (req, res) => {
  const user = db.users.findById(req.params.id);
  res.json({ id: user.id, name: user.name, email: user.email });
});

router.post('/', (req, res) => {
  const created = db.users.create(req.body);
  res.status(201).json(created);
});

router.delete('/:id', (req, res) => {
  db.users.remove(req.params.id);
  res.status(204).end();
});

module.exports = router;
