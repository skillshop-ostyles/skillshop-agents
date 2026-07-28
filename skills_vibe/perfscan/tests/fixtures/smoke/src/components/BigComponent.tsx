'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import Image from 'next/image'

export default function BigComponent() {
  const [count, setCount] = useState(0)
  const router = useRouter()

  return (
    <div>
      <img src="/unoptimized.jpg" alt="" />
      <button onClick={() => setCount((c) => c + 1)}>{count}</button>
      <img src="/banner.jpg" alt="" />
    </div>
  )
}
