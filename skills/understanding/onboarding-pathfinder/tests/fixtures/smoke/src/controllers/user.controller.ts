import { createUser, getUser } from '../services/user.service';

export function handleCreateUser(req: any, res: any) {
  const user = createUser(req.body.email, req.body.name);
  res.status(201).json(user);
}

export function handleGetUser(req: any, res: any) {
  const user = getUser(Number(req.params.id));
  if (!user) return res.status(404).json({ error: 'not found' });
  res.json(user);
}
