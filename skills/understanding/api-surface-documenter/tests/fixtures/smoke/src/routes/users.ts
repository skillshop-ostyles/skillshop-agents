// Fixture for api-surface-documenter: Express REST routes.
import express from 'express';

const app = express();

/**
 * List all users.
 * @returns {User[]}
 */
app.get('/users', (req, res) => {
    res.json([{ id: 1, name: 'Alice' }]);
});

/**
 * Create a new user.
 * @param {string} name - user display name
 */
app.post('/users', (req, res) => {
    res.status(201).json({ id: 2, name: req.body.name });
});

/**
 * Get user by ID.
 * @param {string} id - user identifier
 */
app.get('/users/:id', (req, res) => {
    res.json({ id: req.params.id, name: 'Alice' });
});

/**
 * Delete a user.
 * @param {string} id - user identifier
 */
app.delete('/users/:id', (req, res) => {
    res.status(204).end();
});
