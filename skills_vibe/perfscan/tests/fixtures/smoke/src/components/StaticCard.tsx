'use client'

import data from '../data.json'

export default function StaticCard() {
  return (
    <div>
      <img src="/logo.png" alt="logo" />
      <p>{data.title}</p>
      <img src="/banner.webp" alt="banner" />
    </div>
  )
}
