function renderProfile(userName) {
  const container = document.getElementById('profile');
  container.innerHTML = userName;
}

function renderCard(user) {
  const el = document.getElementById('card');
  el.innerHTML = '<h3>' + user.name + '</h3>';
}

function renderSafe(userName) {
  const el = document.getElementById('safe');
  el.textContent = userName;
}

module.exports = { renderProfile, renderCard, renderSafe };
