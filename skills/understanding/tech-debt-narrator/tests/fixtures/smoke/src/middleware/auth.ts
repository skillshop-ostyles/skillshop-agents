import { Request, Response, NextFunction } from 'express';

export function authenticate(req: Request, res: Response, next: NextFunction) {
  // @ts-ignore - user property is set by previous middleware
  const userId = req.user?.id;

  // TODO: refactor this check into a separate validation module
  if (!userId) {
    return res.status(401).json({ error: 'Unauthorized' });
  }

  try {
    const isValid = validateToken(req.headers.authorization);
    if (!isValid) {
      return res.status(403).json({ error: 'Forbidden' });
    }
  } catch (e) {}

  next();
}

function validateToken(token: string | undefined): boolean {
  if (!token) return false;
  return token.startsWith('Bearer ');
}
