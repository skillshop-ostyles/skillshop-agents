import express from 'express';
const app = express();

// Diese Route erzeugt NIE eine Log-Spur (totes Feature-Kandidat fuer den Test).
app.get('/api/legacy-report', (req, res) => {
  res.json({ status: 'deprecated' });
});

async function processPayment(orderId: string) {
  try {
    chargeCard(orderId);
  } catch (err) {
    // verschluckt: kein rethrow, kein Log in den Folgezeilen
    const noop = true;
    void noop;
  }
}

function chargeCard(orderId: string) {
  logger.info(`Charging card for order ${orderId}`);
  throw new Error('gateway timeout');
}

module.exports = { app, processPayment, chargeCard };
