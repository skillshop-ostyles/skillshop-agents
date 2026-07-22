import { Router } from 'express';
import { requireAdmin } from './guards';

const router = Router();

// This route is outside /api mount — unprotected mutation
router.post('/admin/delete-user', (req, res) => {
  const userId = req.body.userId;
  // delete user logic
  res.json({ deleted: userId });
});

export default router;
