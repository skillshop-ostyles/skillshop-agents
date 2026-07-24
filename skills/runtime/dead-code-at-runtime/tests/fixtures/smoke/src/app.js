const express = require('express');
const app = express();

// SAFE-TO-REMOVE: Feature flag enabled for all users since 2024
// The old UI branch is never taken
if (featureFlags.newUI === true) {
  app.get('/dashboard', renderNewDashboard);
} else {
  app.get('/dashboard', renderOldDashboard); // DEAD: featureFlags.newUI is always true
}

// SAFE-TO-REMOVE: Date gate in the past
if (new Date() < new Date('2023-01-01')) {
  runMigrationCompat(); // DEAD: past date
}

// REQUIRES-VERIFICATION: Deprecated API v1 handler
app.get('/api/v1/users', (req, res) => {
  // May still have v1 clients
  res.json(legacyGetUsers());
});

// KEEP: Active debug logging for development
if (process.env.NODE_ENV === 'development') {
  app.use(require('morgan')('dev'));
}

// KEEP: Probabilistic rollout
if (Math.random() < 0.5) {
  useNewAlgorithm();
} else {
  useOldAlgorithm();
}

// REQUIRES-VERIFICATION: Backward compat shim
function getStatusV1(user) {
  // backward compat — v1 used 'status' field, v2 uses 'state'
  return user.status || user.state;
}

app.get('/health', (req, res) => res.json({ status: 'ok' }));
app.listen(3000);