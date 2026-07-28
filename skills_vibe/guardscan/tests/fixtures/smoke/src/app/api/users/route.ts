import { NextResponse } from 'next/server'

export async function GET() {
  const users = await fetch('https://api.example.com/users').then((r) => r.json())
  return NextResponse.json(users)
}

export async function POST(request: Request) {
  const body = await request.json()

  const result = await fetch('https://api.example.com/users', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  }).then((r) => r.json())

  return NextResponse.json(result, { status: 201 })
}
