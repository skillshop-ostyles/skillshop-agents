import { appConfig } from '../config/app.config';

export function authMiddleware(req: any, res: any, next: any) {
  const token = req.headers.authorization;
  if (!token || token !== `Bearer ${appConfig.jwtSecret}`) {
    return res.status(401).json({ error: 'unauthorized' });
  }
  next();
}
