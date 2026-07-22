// Sync-over-async: blocking call in async method
async function fetchUserData(userId) {
  const user = db.users.findOne({ id: userId });
  // BAD: .Result blocks the async context
  const orders = db.getOrdersAsync(userId).Result;
  return { user, orders };
}

// String concat in loop
function buildReport(items) {
  let result = '';
  for (let i = 0; i < items.length; i++) {
    result += `<li>${items[i].name}</li>`;
  }
  return result;
}

// Hot-loop allocation
function processBatch(items) {
  const results = [];
  for (const item of items) {
    const temp = { id: item.id, name: item.name, timestamp: Date.now() };
    results.push(temp);
  }
  return results;
}

// Listener leak (no cleanup)
class EventManager {
  start() {
    document.addEventListener('click', this.onClick);
  }
}

module.exports = { fetchUserData, buildReport, processBatch, EventManager };
