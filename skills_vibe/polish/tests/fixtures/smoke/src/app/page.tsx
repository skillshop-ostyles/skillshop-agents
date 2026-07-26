'use client'

import { useEffect, useState } from 'react'
import { fetchUsers } from '../lib/api'
import type { User } from '../types'

export default function HomePage() {
  const [data, setData] = useState<any>(null)
  const [error, setError] = useState<any>(null)

  useEffect(() => {
    fetchUsers()
      .then((res: any) => setData(res))
      .catch((err: any) => {
        console.error('fetch failed:', err)
        setError(err)
      })
  }, [])

  console.log('HomePage rendered', data)

  return (
    <div>
      <h1>Users</h1>
      {data?.map((user: any) => (
        <div>{user.name}</div>
      ))}
    </div>
  )
}
