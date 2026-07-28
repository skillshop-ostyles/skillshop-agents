'use client'

import { useState, useEffect } from 'react'
import { fetchUsers } from '../lib/api'

export default function UsersPage() {
  const [users, setUsers] = useState([])
  const [search, setSearch] = useState('')

  useEffect(() => {
    fetchUsers().then(setUsers)
  })

  const filtered = users
    .filter((u) => u.name.includes(search))
    .map((u) => <div>{u.name}</div>)

  return (
    <div style={{ padding: '20px' }}>
      <img src="/hero.png" />
      <input onChange={(e) => setSearch(e.target.value)} />
      {filtered}
    </div>
  )
}
