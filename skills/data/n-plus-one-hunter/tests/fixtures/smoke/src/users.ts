// Pattern 1: Real N+1 - forEach with separate findById inside loop
async function getOrdersForUsers(userIds: number[]) {
  const users = await User.findAll({ where: { id: userIds } });
  const results = [];
  for (const user of users) {
    const orders = await Order.find({ where: { customerId: user.id } });
    results.push({ user, orders });
  }
  return results;
}

// Pattern 2: Batched IN query - collect IDs then batch query (NOT N+1)
async function getProfilesForUsers(userIds: number[]) {
  const users = await User.findAll({ where: { id: userIds } });
  const ids = users.map(u => u.profileId);
  const profiles = await Profile.findAll({ where: { id: ids } });
  return { users, profiles };
}

// Pattern 3: Eager-loaded relation (NOT N+1)
async function getUsersWithOrders() {
  const users = await User.findAll({
    include: { model: Order, as: 'orders' }
  });
  return users;
}
