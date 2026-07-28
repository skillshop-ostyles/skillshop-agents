import { useState, useEffect, useRef, useCallback, useMemo } from 'react'
import { useRouter, useSearchParams, usePathname } from 'next/navigation'
import Image from 'next/image'
import Link from 'next/link'
import { format } from 'date-fns'
import { z } from 'zod'
import { clsx } from 'clsx'
import { toast } from 'sonner'
import { useQuery } from '@tanstack/react-query'
import { useSession } from 'next-auth/react'
import { useTheme } from 'next-themes'
import { useMediaQuery } from 'usehooks-ts'
import { motion } from 'framer-motion'
import { Header } from './Header'
import { Footer } from './Footer'
import { Sidebar } from './Sidebar'
import { Card } from './Card'
import { Button } from './Button'
import { Modal } from './Modal'
import { Spinner } from './Spinner'
import { EmptyState } from './EmptyState'
import { ErrorBoundary } from './ErrorBoundary'
import { Pagination } from './Pagination'
import { SearchInput } from './SearchInput'
import { FilterBar } from './FilterBar'
import { SortDropdown } from './SortDropdown'
import { Table } from './Table'
import { Badge } from './Badge'
import { Avatar } from './Avatar'
import { Tooltip } from './Tooltip'
import { Dropdown } from './Dropdown'
import { Progress } from './Progress'

interface Item {
  id: string
  name: string
  description: string
  createdAt: string
  updatedAt: string
  status: 'active' | 'inactive' | 'archived'
  priority: number
  tags: string[]
  assignedTo: string | null
}

export default function HugeList() {
  const [items, setItems] = useState<Item[]>([])
  const [search, setSearch] = useState('')
  const [sortBy, setSortBy] = useState('name')
  const [filter, setFilter] = useState('all')
  const [page, setPage] = useState(1)
  const [selected, setSelected] = useState<string[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const router = useRouter()
  const searchParams = useSearchParams()
  const pathname = usePathname()

  const { data: session } = useSession()
  const { theme } = useTheme()
  const isMobile = useMediaQuery('(max-width: 768px)')

  useEffect(() => {
    fetch('/api/items').then((r) => r.json()).then(setItems).finally(() => setIsLoading(false))
  }, [])

  const filtered = useMemo(() => {
    return items.filter((i) => i.name.includes(search))
  }, [items, search])

  const sorted = useMemo(() => {
    return [...filtered].sort((a, b) => {
      if (sortBy === 'name') return a.name.localeCompare(b.name)
      if (sortBy === 'priority') return b.priority - a.priority
      return 0
    })
  }, [filtered, sortBy])

  const paginated = useMemo(() => {
    const perPage = 20
    return sorted.slice((page - 1) * perPage, page * perPage)
  }, [sorted, page])

  const totalPages = Math.ceil(sorted.length / 20)

  const handleSelect = useCallback((id: string) => {
    setSelected((prev) => prev.includes(id) ? prev.filter((x) => x !== id) : [...prev, id])
  }, [])

  const handleDelete = useCallback(async () => {
    if (!confirm('Delete selected items?')) return
    await fetch('/api/items/batch-delete', {
      method: 'POST',
      body: JSON.stringify({ ids: selected }),
    })
    setItems((prev) => prev.filter((i) => !selected.includes(i.id)))
    setSelected([])
    toast.success('Deleted')
  }, [selected])

  if (isLoading) return <Spinner />
  if (error) return <EmptyState message={error} />

  return (
    <div>
      <Header
        title="Items"
        actions={
          selected.length > 0 && (
            <Button variant="danger" onClick={handleDelete}>
              Delete {selected.length}
            </Button>
          )
        }
      />
      <div>
        <SearchInput value={search} onChange={setSearch} />
        <FilterBar value={filter} onChange={setFilter} />
        <SortDropdown value={sortBy} onChange={setSortBy} />
      </div>
      <Table>
        {paginated.map((item) => (
          <div key={item.id}>
            <input
              type="checkbox"
              checked={selected.includes(item.id)}
              onChange={() => handleSelect(item.id)}
            />
            <Avatar name={item.name} />
            <div>
              <Link href={`/items/${item.id}`}>{item.name}</Link>
              <p>{item.description}</p>
              <div>
                {item.tags.map((tag) => (
                  <Badge key={tag}>{tag}</Badge>
                ))}
              </div>
              <p>Priority: {item.priority}</p>
              <p>Created: {format(new Date(item.createdAt), 'PP')}</p>
              <Tooltip content={item.status}>
                <Badge variant={item.status === 'active' ? 'success' : 'warning'}>
                  {item.status}
                </Badge>
              </Tooltip>
            </div>
          </div>
        ))}
      </Table>
      <Pagination
        current={page}
        total={totalPages}
        onPageChange={setPage}
      />
      <Footer />
    </div>
  )
}
