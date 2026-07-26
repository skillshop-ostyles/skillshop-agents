export type User = {
  id: string
  name: string
  email: string
  createdAt: string
  posts?: Post[]
}

export type Post = {
  id: string
  title: string
  body: string
}
