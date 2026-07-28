'use client'

import { useSession } from 'next-auth/react'
import { useRouter } from 'next/navigation'
import { useEffect } from 'react'

export default function ProtectedDashboard() {
  const { data: session } = useSession()
  const router = useRouter()

  useEffect(() => {
    if (!session) {
      router.push('/login')
    }
  }, [session, router])

  if (!session) {
    return <div>Redirecting...</div>
  }

  return (
    <div>
      <h1>Welcome, {session.user?.name}</h1>
      <p>This dashboard is protected — but only in the browser.</p>
    </div>
  )
}
