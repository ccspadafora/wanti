import { useEffect, useState, type FormEvent } from 'react'
import { api, type ApiError } from '../lib/api'
import { useAuth } from '../lib/auth'

type Tag = {
  id: string
  code: string
  label: string
  for_role: string
  order: number
  is_active: boolean
}

export function ReviewTagsPage() {
  const { user } = useAuth()
  const isAdmin = user?.role === 'ADMIN'
  const [rows, setRows] = useState<Tag[]>([])
  const [error, setError] = useState('')
  const [form, setForm] = useState({
    code: '',
    label: '',
    for_role: 'BUYER_REVIEWING_SELLER',
    order: '0',
  })

  async function load() {
    try {
      setRows(await api<Tag[]>('/admin/review-tags/'))
    } catch (e) {
      setError((e as ApiError).message)
    }
  }

  useEffect(() => {
    load()
  }, [])

  async function create(e: FormEvent) {
    e.preventDefault()
    if (!isAdmin) return
    try {
      await api('/admin/review-tags/', {
        method: 'POST',
        body: JSON.stringify({
          ...form,
          order: Number(form.order),
          is_active: true,
        }),
      })
      setForm({ code: '', label: '', for_role: form.for_role, order: '0' })
      await load()
    } catch (err) {
      setError((err as ApiError).message)
    }
  }

  async function toggle(tag: Tag) {
    if (!isAdmin) return
    try {
      await api(`/admin/review-tags/${tag.id}/`, {
        method: 'PATCH',
        body: JSON.stringify({ is_active: !tag.is_active }),
      })
      await load()
    } catch (e) {
      setError((e as ApiError).message)
    }
  }

  return (
    <div>
      <h1 className="page-title">Tags de reseñas</h1>
      <p className="page-sub">Etiquetas que aparecen al calificar</p>
      {error && <p className="error">{error}</p>}
      {isAdmin && (
        <form className="card" onSubmit={create} style={{ marginBottom: 16 }}>
          <div className="toolbar">
            <input
              placeholder="CODE"
              value={form.code}
              onChange={(e) => setForm({ ...form, code: e.target.value })}
              required
            />
            <input
              placeholder="Label"
              value={form.label}
              onChange={(e) => setForm({ ...form, label: e.target.value })}
              required
            />
            <select
              value={form.for_role}
              onChange={(e) => setForm({ ...form, for_role: e.target.value })}
            >
              <option value="BUYER_REVIEWING_SELLER">Comprador → Vendedor</option>
              <option value="SELLER_REVIEWING_BUYER">Vendedor → Comprador</option>
            </select>
            <button className="btn btn-primary" type="submit">
              Crear
            </button>
          </div>
        </form>
      )}
      <div className="card table-wrap">
        <table className="data">
          <thead>
            <tr>
              <th>Code</th>
              <th>Label</th>
              <th>Rol</th>
              <th>Estado</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {rows.map((t) => (
              <tr key={t.id}>
                <td>{t.code}</td>
                <td>{t.label}</td>
                <td>{t.for_role}</td>
                <td>
                  <span className={`badge ${t.is_active ? 'ok' : 'danger'}`}>
                    {t.is_active ? 'Activo' : 'Off'}
                  </span>
                </td>
                <td>
                  {isAdmin && (
                    <button className="btn btn-ghost" onClick={() => toggle(t)}>
                      Toggle
                    </button>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  )
}
