import { Router } from 'express';
const router = Router();

router.post('/orders', (req, res) => {
  res.json({ id: '123' });
});
