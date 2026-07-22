export function authMiddleware(req: any, res: any, next: any) {
  if (!req.headers.authorization) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  next();
}
