// Query that joins orders to customers (matches declared FK)
const getOrdersWithCustomers = `
    SELECT o.id, o.total, c.name
    FROM orders o
    JOIN customers c ON o.customer_id = c.id
`;

// Query that joins orders to users (matches inferred FK: created_by -> users.id)
const getOrdersWithCreators = `
    SELECT o.id, u.username
    FROM orders o
    JOIN users u ON o.created_by = u.id
`;
