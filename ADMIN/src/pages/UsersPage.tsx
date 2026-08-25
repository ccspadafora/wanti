import { useEffect, useState, type FormEvent } from 'react'
import { Link } from 'react-router-dom'
import { api, qs, type ApiError, type Paginated } from '../lib/api'

type UserRow = {
  id: string
  email: string
  full_name: string
  phone: string
  city: string
  role: string
  status: string
  rating_average?: number
}

const emptyCreate = {
  email: '',
  password: '',
  full_name: '',
  id_type: 'CC',
  id_number: '',
  phone: '',
  city: 'Bogota',
  role: 'USER',
  status: 'ACTIVE',
}

export function UsersPage() {
  const [rows, setRows] = useState<UserRow[]>([])
  const [search, setSearch] = useState('')
  const [status, setStatus] = useState('')
  const [role, setRole] = useState('')
  const [error, setError] = useState('')
  const [msg, setMsg] = useState('')
  const [loading, setLoading] = useState(true)
  const [showCreate, setShowCreate] = useState(false)
  const [form, setForm] = useState(emptyCreate)
  const [busy, setBusy] = useState(false)

  async function load() {
    setLoading(true)
    setError('')
    try {
      const data = await api<Paginated<UserRow>>(
        `/admin/users/${qs({ search, status, role })}`,
      )
      setRows(data.results || [])
    } catch (e) {
      setError((e as ApiError).message)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    load()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  async function create(e: FormEvent) {
    e.preventDefault()
    setBusy(true)
    setError('')
    setMsg('')
    try {
      const created = await api<UserRow>('/admin/users/', {
        method: 'POST',
        body: JSON.stringify({
          ...form,
          verify_email: true,
          verify_phone: true,
        }),
      })
      setMsg(`Usuario creado: ${created.email}`)
      setForm(emptyCreate)
      setShowCreate(false)
      await load()
    } catch (err) {
      setError((err as ApiError).message)
    } finally {
      setBusy(false)
    }
  }

  return (
    <div>
      <div className="dash-header">
        <div>
          <h1 className="page-title">Usuarios</h1>
          <p className="page-sub" style={{ marginBottom: 0 }}>
            Crear, suspender, activar y revisar perfiles
          </p>
        </div>
        <button className="btn btn-primary" type="button" onClick={() => setShowCreate((v) => !v)}>
          {showCreate ? 'Cerrar' : 'Nuevo usuario'}
        </button>
      </div>

      {showCreate && (
        <form className="card" onSubmit={create} style={{ marginBottom: 18 }}>
          <h3 style={{ marginTop: 0 }}>Nuevo usuario</h3>
          <div className="toolbar" style={{ flexWrap: 'wrap' }}>
            <input
              placeholder="Nombre completo"
              value={form.full_name}
              onChange={(e) => setForm({ ...form, full_name: e.target.value })}
              required
            />
            <input
              type="email"
              placeholder="Email"
              value={form.email}
              onChange={(e) => setForm({ ...form, email: e.target.value })}
              required
            />
            <input
              type="password"
              placeholder="Contraseña"
              value={form.password}
              onChange={(e) => setForm({ ...form, password: e.target.value })}
              required
              minLength={8}
            />
            <select value={form.id_type} onChange={(e) => setForm({ ...form, id_type: e.target.value })}>
              <option value="CC">CC</option>
              <option value="CE">CE</option>
              <option value="PASSPORT">PASSPORT</option>
              <option value="NIT">NIT</option>
            </select>
            <input
              placeholder="Documento"
              value={form.id_number}
              onChange={(e) => setForm({ ...form, id_number: e.target.value })}
              required
            />
            <input
              placeholder="Teléfono"
              value={form.phone}
              onChange={(e) => setForm({ ...form, phone: e.target.value })}
              required
            />
            <input
              placeholder="Ciudad"
              value={form.city}
              onChange={(e) => setForm({ ...form, city: e.target.value })}
              required
            />
            <select value={form.role} onChange={(e) => setForm({ ...form, role: e.target.value })}>
              <option value="USER">USER</option>
              <option value="MODERATOR">MODERATOR</option>
              <option value="ADMIN">ADMIN</option>
            </select>
            <button className="btn btn-primary" type="submit" disabled={busy}>
              Crear
            </button>
          </div>
        </form>
      )}

      <div className="toolbar">
        <input
          placeholder="Buscar email / nombre"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
        />
        <select value={status} onChange={(e) => setStatus(e.target.value)}>
          <option value="">Todos los estados</option>
          <option value="ACTIVE">ACTIVE</option>
          <option value="PENDING">PENDING</option>
          <option value="SUSPENDED">SUSPENDED</option>
        </select>
        <select value={role} onChange={(e) => setRole(e.target.value)}>
          <option value="">Todos los roles</option>
          <option value="USER">USER</option>
          <option value="ADMIN">ADMIN</option>
          <option value="MODERATOR">MODERATOR</option>
        </select>
        <button className="btn btn-navy" onClick={load} disabled={loading}>
          Filtrar
        </button>
      </div>
      {error && <p className="error">{error}</p>}
      {msg && <p className="muted">{msg}</p>}
      <div className="card table-wrap">
        <table className="data">
          <thead>
            <tr>
              <th>Nombre</th>
              <th>Email</th>
              <th>Ciudad</th>
              <th>Rol</th>
              <th>Estado</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {rows.map((u) => (
              <tr key={u.id}>
                <td>{u.full_name}</td>
                <td>{u.email}</td>
                <td>{u.city}</td>
                <td>
                  <span className="badge">{u.role}</span>
                </td>
                <td>
                  <span
                    className={`badge ${u.status === 'ACTIVE' ? 'ok' : u.status === 'SUSPENDED' ? 'danger' : 'warn'}`}
                  >
                    {u.status}
                  </span>
                </td>
                <td>
                  <Link to={`/users/${u.id}`}>Ver</Link>
                </td>
              </tr>
            ))}
            {!loading && rows.length === 0 && (
              <tr>
                <td colSpan={6} className="muted">
                  Sin resultados
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  )
}
