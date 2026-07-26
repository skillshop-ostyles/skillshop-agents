const openai = new OpenAI({
  apiKey: 'sk-proj-abc123def456ghi789jkl012',
})

export async function fetchUsers() {
  const res = await fetch('/api/users')
  return res.json()
}
