const users = {
  findById(id) { return { id, name: 'Test', email: 'test@example.com' }; },
  create(data) { return { id: Date.now(), ...data }; },
  remove(id) { return true; }
};

const orders = {
  create(data) { return { id: Date.now(), ...data, status: 'pending' }; },
  getStatus(id) { return 'shipped'; }
};

module.exports = { users, orders };
