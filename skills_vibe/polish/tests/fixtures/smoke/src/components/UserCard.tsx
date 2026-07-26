import { useState } from 'react'
import { fetchUserById } from '../lib/api'
import { formatDate } from 'date-fns'
import { z } from 'zod'

interface UserCardProps {
  userId: string
}

export default function UserCard({ userId }: UserCardProps) {
  const [user, setUser] = useState<any>(null)

  useState(() => {
    fetchUserById(userId).then((res: any) => {
      setUser(res)
    })
  }, [userId])

  if (!user) return <div>Loading...</div>

  return (
    <div className="card">
      <h2>{user.name}</h2>
      <p>{formatDate(user.createdAt, 'PP')}</p>
      <div>
        {user.posts?.map((post: any) => (
          <div className="post">{post.title}</div>
        ))}
      </div>
    </div>
  )
}
