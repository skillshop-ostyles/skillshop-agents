// CRASH RISK: JSON.parse result used without validation
function parseUser(input: string) {
  const data = JSON.parse(input);
  return data.name; // crashes if input is not {name: string}
}

// CRASH RISK: API response without schema check
async function fetchUser(id: number) {
  const res = await fetch(`/api/users/${id}`);
  const data = await res.json();
  return data.email.toUpperCase(); // crashes if email is missing
}

// SAFE: Optional chaining handles undefined
function getCity(user: any) {
  return user?.address?.city; // safe, gracefully returns undefined
}

// SAFE: Zod-validated API response
import { z } from 'zod';
const UserSchema = z.object({ name: z.string(), email: z.string() });
async function safeFetch(id: number) {
  const res = await fetch(`/api/users/${id}`);
  const data = await res.json();
  const validated = UserSchema.parse(data);
  return validated.name; // safe, validated
}

// SAFE: Array with length check
function first(items: string[]) {
  if (items.length > 0) {
    return items[0]; // safe
  }
  return null;
}