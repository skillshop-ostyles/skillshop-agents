const db = require('some-db');

function getByEmail(email) {
    // email has no index -> missing-index (major)
    return db.query('SELECT * FROM users WHERE email = ?', [email]);
}

function getByStatus(status) {
    // status has index -> no mismatch
    return db.query('SELECT * FROM users WHERE status = ?', [status]);
}

function getByNonExistent(val) {
    // non_existent column doesn't exist -> missing-column (critical)
    return db.query('SELECT * FROM users WHERE non_existent = ?', [val]);
}

function getUsersWithOrders(userId) {
    // users.name has no index -> missing-index (major)
    // orders.customer_name also has no index -> missing-index (major)
    return db.query('SELECT u.*, o.* FROM users u JOIN orders o ON u.name = o.customer_name WHERE u.id = ?', [userId]);
}
