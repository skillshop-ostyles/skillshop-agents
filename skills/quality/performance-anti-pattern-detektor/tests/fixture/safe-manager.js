// Safe: listener with cleanup — should NOT be flagged
class SafeManager {
  start() {
    this.boundClick = this.onClick.bind(this);
    document.addEventListener('click', this.boundClick);
  }
  stop() {
    document.removeEventListener('click', this.boundClick);
  }
}

module.exports = { SafeManager };
