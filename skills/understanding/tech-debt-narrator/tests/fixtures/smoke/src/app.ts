import express from 'express';
import { authenticate } from './middleware/auth';
import { getUsers } from './services/user';
import { listProducts } from './services/product';
import { chargeCustomer } from './payment/charge';
import { formatCurrency } from './utils/format';
import { config } from './config/app';

const app = express();

// eslint-disable-next-line @typescript-eslint/no-unused-vars
app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

app.post('/users', authenticate, async (req, res) => {
  const users = await getUsers();
  res.json(users);
});

app.get('/products', async (req, res) => {
  const products = await listProducts(req.query.category as string);
  res.json(products);
});

// eslint-disable-next-line @typescript-eslint/no-explicit-any
app.post('/charge', authenticate, async (req: any, res: any) => {
  const { amount, paymentMethodId } = req.body;
  const result = await chargeCustomer(amount, paymentMethodId);
  res.json(result);
});

app.listen(config.port, () => {
  console.log(`Server running on port ${config.port}`);
});
