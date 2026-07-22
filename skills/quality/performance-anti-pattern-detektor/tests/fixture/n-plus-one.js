const db = require('./db');

// N+1 query — database call inside loop
function getOrderDetails(orderIds) {
  const results = [];
  orderIds.forEach(id => {
    const details = db.query(`SELECT * FROM order_details WHERE order_id = ${id}`);
    results.push(details);
  });
  return results;
}

// Safe: batched query (DataLoader pattern — should NOT be flagged)
async function getUsersBatched(userIds) {
  const { PrismaClient } = require('@prisma/client');
  const prisma = new PrismaClient();
  return await prisma.user.findMany({
    where: { id: { in: userIds } },
    include: { posts: true }
  });
}

module.exports = { getOrderDetails, getUsersBatched };
