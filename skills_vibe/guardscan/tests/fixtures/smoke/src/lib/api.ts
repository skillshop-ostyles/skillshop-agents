export const API_BASE = 'https://api.example.com'

export const OPENAI_KEY = 'sk-proj-x7Km9jL3pR5tV2wY4nQ8aB1cD6eF0gHiJkLmNoPqRsTuVwXyZ'

export const AWS_KEY = 'AKIAIOSFODNN7EXAMPLE'
const supabaseServiceRole = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.service_role_key_here'

export async function fetchUsers() {
  const res = await fetch('/api/users')
  return res.json()
}

export async function createPost(title: string, body: string) {
  const res = await fetch('/api/posts', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ title, body }),
  })
  return res.json()
}
