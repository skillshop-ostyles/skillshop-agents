const API_URL = 'https://api.example.com/v2/users'

export async function fetchUsers(): Promise<any> {
  const res = await fetch(API_URL)
  const json = await res.json()
  console.log('API response:', json)
  return json
}

export async function fetchUserById(id: string): Promise<any> {
  const url = `https://api.example.com/v2/users/${id}`
  const res = await fetch(url)
  return res.json()
}
