// Fixture for type-confusion-bypass-detector.
// Scenarios: proper validation, incomplete validation, missing validation,
// unsafe rendering, NoSQL injection via object input.

const express = require('express');
const mongoose = require('mongoose');

const app = express();
app.use(express.json());

// ---------------------------------------------------------------------------
// Scenario 1: Proper type + length validation before DB query.
// Attacker sends str → passes type check → passes length check → safe query.
// Edge case: array input fails typeof check → rejected.
// ---------------------------------------------------------------------------
app.get('/user/:id', async (req, res) => {
    const id = req.params.id;

    if (typeof id !== 'string') {
        return res.status(400).json({ error: 'id must be a string' });
    }
    if (id.length < 1 || id.length > 64) {
        return res.status(400).json({ error: 'id length out of range' });
    }

    const user = await User.findById(id);
    res.json(user);
});

// ---------------------------------------------------------------------------
// Scenario 2: Only type check (no length/regex), array input could bypass.
// Edge case: array passes typeof check (arrays are objects in JS).
// Mongoose treats arrays differently in queries.
// ---------------------------------------------------------------------------
app.post('/login', async (req, res) => {
    const username = req.body.username;
    const password = req.body.password;

    if (typeof username !== 'string') {
        return res.status(400).json({ error: 'username must be a string' });
    }

    // No length check, no regex validation — username could be a crafted string
    const user = await User.findOne({ username: username, password: password });
    res.json(user);
});

// ---------------------------------------------------------------------------
// Scenario 3: No validation, input goes directly to query sink.
// Attacker sends object { $gt: '' } → MongoDB NoSQL injection.
// ---------------------------------------------------------------------------
app.post('/search', async (req, res) => {
    const query = req.body.query;

    // No validation whatsoever — object input with $ operators passes through
    const results = await Item.find({ name: query });
    res.json(results);
});

// ---------------------------------------------------------------------------
// Scenario 4: Input validated but template rendering uses unsafe method.
// Type validation passes but the sink is dangerouslySetInnerHTML.
// ---------------------------------------------------------------------------
app.get('/preview/:title', (req, res) => {
    const title = req.params.title;

    if (typeof title !== 'string' || title.length > 200) {
        return res.status(400).json({ error: 'invalid title' });
    }

    // Unsafe rendering — XSS via title even though validation was basic
    res.render('preview', { title: title });
    // Equivalent to: element.innerHTML = title;
});

// ---------------------------------------------------------------------------
// Scenario 5: NoSQL injection via object input to MongoDB query.
// Type check passes because typeof {} === 'object', not checked.
// ---------------------------------------------------------------------------
app.get('/lookup', async (req, res) => {
    const filter = req.body.filter;

    // No type check — attacker sends { $ne: null } as filter
    // MongoDB interprets $ne as "not equal" → returns all documents
    const doc = await Doc.findOne(filter);
    res.json(doc);
});
