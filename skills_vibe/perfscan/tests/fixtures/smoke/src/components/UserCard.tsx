'use client'

import { fetchUserById } from '../lib/api'

export default function UserCard({ userId }: { userId: string }) {
  const user = fetchUserById(userId)

  return (
    <div onClick={() => alert('clicked')}>
      <img src={`https://example.com/avatars/${userId}.jpg`} />
      {user?.posts?.map((p) => (
        <div className="post">{p.title}</div>
      ))}
    </div>
  )
}
