import { useEffect, useState, type FormEvent } from 'react'
import { api, qs, type ApiError, type Paginated } from '../lib/api'

type UserOpt = { id: string; email: string; full_name: string }

type Row = {
  id: string
  recipient_email?: string
  channel: string
  template_code: string
  title: string
  body: string
  delivery_status: string
  created_at: string
}

export function NotificationsPage() {
  const [rows, setRows] = useState<Row[]>([])
  const [users, setUsers] = useState<UserOpt[]>([])
  const [delivery, setDelivery] = useState('')
  const [channel, setChannel] = useState('')
  const [error, setError] = useState('')
  const [msg, setMsg] = useState('')
  const [showCreate, setShowCreate] = useState(false)
  const [busy, setBusy] = useState(false)
  const [form, setForm] = useState({
    recipient_id: '',
    title: '',
    body: '',
  })

  async function load() {
    setError('')
    try {
      const data = await api<Paginated<Row>>(
        `/admin/notifications/${qs({ delivery_status: delivery, channel })}`,
      )
      setRows(data.results || [])
    } catch (e) {
      setError((e as ApiError).message)
    }
  }

  async function loadUsers() {
    try {
      const data = await api<Paginated<UserOpt>>('/admin/users/?page_size=100')
      setUsers(data.results || [])
    } catch {
      /* ignore */
    }
  }

  useEffect(() => {
    load()
    loadUsers()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  async function create(e: FormEvent) {
    e.preventDefault()
    setBusy(true)
    setError('')
    setMsg('')
    try {
      await api('/admin/notifications/', {
        method: 'POST',
        body: JSON.stringify(form),
      })
      setMsg('Notificación creada')
      setForm({ recipient_id: '', title: '', body: '' })
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
          <h1 className="page-title">Notificaciones</h1>
          <p className="page-sub" style={{ marginBottom: 0 }}>
            Inbox / envíos registrados · crear aviso manual a un usuario
          </p>
        </div>
        <button className="btn btn-primary" type="button" onClick={() => setShowCreate((v) => !v)}>
          {showCreate ? 'Cerrar' : 'Nueva notificación'}
        </button>
      </div>

      {showCreate && (
        <form className="card" onSubmit={create} style={{ marginBottom: 18 }}>
          <h3 style={{ marginTop: 0 }}>Nueva notificación</h3>
          <div className="toolbar" style={{ flexWrap: 'wrap' }}>
            <select
              value={form.recipient_id}
              onChange={(e) => setForm({ ...form, recipient_id: e.target.value })}
              required
            >
              <option value="">Destinatario…</option>
              {users.map((u) => (
                <option key={u.id} value={u.id}>
                  {u.full_name} — {u.email}
                </option>
              ))}
            </select>
            <input
              placeholder="Título"
              value={form.title}
              onChange={(e) => setForm({ ...form, title: e.target.value })}
              required
            />
            <input
              placeholder="Mensaje"
              value={form.body}
              onChange={(e) => setForm({ ...form, body: e.target.value })}
              required
              style={{ minWidth: 280 }}
            />
            <button className="btn btn-primary" type="submit" disabled={busy}>
              Crear
            </button>
          </div>
        </form>
      )}

      <div className="toolbar">
        <select value={delivery} onChange={(e) => setDelivery(e.target.value)}>
          <option value="">Todos los estados</option>
          <option value="PENDING">PENDING</option>
          <option value="SENT">SENT</option>
          <option value="DELIVERED">DELIVERED</option>
          <option value="FAILED">FAILED</option>
        </select>
        <select value={channel} onChange={(e) => setChannel(e.target.value)}>
          <option value="">Todos los canales</option>
          <option value="PUSH">PUSH</option>
          <option value="EMAIL">EMAIL</option>
          <option value="WHATSAPP">WHATSAPP</option>
          <option value="SMS">SMS</option>
        </select>
        <button className="btn btn-navy" onClick={load}>
          Filtrar
        </button>
      </div>
      {error && <p className="error">{error}</p>}
      {msg && <p className="muted">{msg}</p>}
      <div className="card table-wrap">
        <table className="data">
          <thead>
            <tr>
              <th>Destinatario</th>
              <th>Canal</th>
              <th>Plantilla</th>
              <th>Estado</th>
              <th>Contenido</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((r) => (
              <tr key={r.id}>
                <td>{r.recipient_email || '—'}</td>
                <td>{r.channel}</td>
                <td>{r.template_code}</td>
                <td>
                  <span className={`badge ${r.delivery_status === 'FAILED' ? 'danger' : 'ok'}`}>
                    {r.delivery_status}
                  </span>
                </td>
                <td>
                  <div>{r.title}</div>
                  <div className="muted">{r.body?.slice(0, 120)}</div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  )
}
