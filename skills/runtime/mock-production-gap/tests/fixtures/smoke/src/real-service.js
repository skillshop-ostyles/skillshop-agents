function getUser(id) {
  return {
    id: id,
    email: 'user@example.com',
    status: 'active',
    createdAt: new Date()
  };
}

module.exports = { getUser };
