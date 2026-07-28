import LoginForm from '../components/LoginForm'

export default function Home() {
  const dbUrl = process.env.DATABASE_URL
  const apiKey = process.env.API_KEY

  return (
    <main>
      <h1>My App</h1>
      <LoginForm />
    </main>
  )
}
