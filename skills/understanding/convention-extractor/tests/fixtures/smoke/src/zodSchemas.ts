import { z } from 'zod';

export const UserSchema = z.object({
  id: z.string().uuid(),
  name: z.string().min(1),
  email: z.string().email(),
  role: z.enum(['admin', 'user']).default('user'),
});

export type User = z.infer<typeof UserSchema>;

export const ProductSchema = z.object({
  id: z.string(),
  name: z.string(),
  price: z.number().positive(),
});

export type Product = z.infer<typeof ProductSchema>;
