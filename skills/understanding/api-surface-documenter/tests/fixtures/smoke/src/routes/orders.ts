// Fixture for api-surface-documenter: Express router REST routes.
import { Router } from 'express';

const router = Router();

/**
 * Create a new order.
 * @param {string} productId - product to order
 */
router.post('/orders', (req, res) => {
    res.status(201).json({ orderId: 101 });
});

/**
 * Get order by ID.
 * @param {string} id - order identifier
 */
router.get('/orders/:id', (req, res) => {
    res.json({ id: req.params.id, product: 'Widget' });
});

export default router;
