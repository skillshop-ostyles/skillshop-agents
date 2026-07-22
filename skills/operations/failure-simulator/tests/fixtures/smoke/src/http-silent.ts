import { httpClient } from './client';

export async function fetchData(url: string) {
  try {
    const response = await httpClient.get(url);
    return response.data;
  } catch {
    // silently ignore
  }
}
