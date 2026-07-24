// Clean query
const q1 = "SELECT id, name, email FROM users WHERE status = 'active'";

// SELECT *
const q2 = "SELECT * FROM orders JOIN customers ON orders.customer_id = customers.id";

// Non-sargable LIKE
const q3 = "SELECT * FROM products WHERE description LIKE '%discount%'";
