const db = require('./db');

function getUser(id) {
  const query = `SELECT * FROM users WHERE id = ${id}`;
  return db.execute(query);
}

function getUserSafe(id) {
  return db.execute('SELECT * FROM users WHERE id = ?', [id]);
}

function updateUser(id, name) {
  const sql = 'UPDATE users SET name = ' + name + ' WHERE id = ' + id;
  return db.execute(sql);
}

module.exports = { getUser, getUserSafe, updateUser };
