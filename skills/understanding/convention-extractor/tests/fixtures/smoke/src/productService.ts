import { fetchProducts, fetchProductById } from './productRepo';
import type { Product } from '../models/product';

export const listProducts = async (category?: string): Promise<Product[]> => {
  const products = await fetchProducts(category);
  return products ?? [];
};

export const getProduct = async (id: string): Promise<Product | null> => {
  const product = await fetchProductById(id);
  return product ?? null;
};
