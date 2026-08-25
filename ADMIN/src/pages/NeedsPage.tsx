import { useEffect, useState, type FormEvent } from 'react'
import { api, qs, type ApiError, type Paginated } from '../lib/api'

type UserOpt = { id: string; email: string; full_name: string }

type NeedRow = {
  id: string
  title: string
  description?: string
  asset_type: string
  city: string
  status: string
  budget_max_cop: string | number
  payment_type?: string
  matches_count: number
  created_at: string
}

const emptyEdit = {
  title: '',
  description: '',
  city: '',
  budget_max_cop: '',
  payment_type: 'CASH',
  status: 'ACTIVE',
}

const emptyCreate = {
  buyer_id: '',
  asset_type: 'VEHICLE',
  title: '',
  description: '',
  budget_max_cop: '50000000',
  payment_type: 'CASH',
  city: 'Bogota',
  brand: '',
  model: '',
  property_type: 'APTO',
  publish: true,
}

export function NeedsPage() {
  const [rows, setRows] = useState<NeedRow[]>([])
  const [users, setUsers] = useState<UserOpt[]>([])
  const [status, setStatus] = useState('')
  const [error, setError] = useState('')
  const [busyId, setBusyId] = useState('')
  const [editing, setEditing] = useState<NeedRow | null>(null)
  const [form, setForm] = useState(emptyEdit)
  const [createForm, setCreateForm] = useState(emptyCreate)
  const [showCreate, setShowCreate] = useState(false)
  const [msg, setMsg] = useState('')
  const [busy, setBusy] = useState(false)

  async function load() {
    setError('')
    try {
      const data = await api<Paginated<NeedRow>>(`/admin/needs/${qs({ status })}`)
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

  function openEdit(n: NeedRow) {
    setEditing(n)
    setForm({
      title: n.title || '',
      description: n.description || '',
      city: n.city || '',
      budget_max_cop: String(n.budget_max_cop ?? ''),
      payment_type: n.payment_type || 'CASH',
      status: n.status,
    })
    setMsg('')
  }

  async function saveEdit(e: FormEvent) {
    e.preventDefault()
    if (!editing) return
    setBusyId(editing.id)
    setError('')
    setMsg('')
    try {
      await api(`/admin/needs/${editing.id}/`, {
        method: 'PATCH',
        body: JSON.stringify({
          title: form.title,
          description: form.description,
          city: form.city,
          budget_max_cop: form.budget_max_cop,
          payment_type: form.payment_type,
          status: form.status,
        }),
      })
      setMsg('Necesidad actualizada')
      setEditing(null)
      await load()
    } catch (err) {
      setError((err as ApiError).message)
    } finally {
      setBusyId('')
    }
  }

  async function create(e: FormEvent) {
    e.preventDefault()
    setBusy(true)
    setError('')
    setMsg('')
    try {
      await api('/admin/needs/', {
        method: 'POST',
        body: JSON.stringify(createForm),
      })
      setMsg('Necesidad creada')
      setCreateForm(emptyCreate)
      setShowCreate(false)
      await load()
    } catch (err) {
      setError((err as ApiError).message)
    } finally {
      setBusy(false)
    }
  }

  async function flag(id: string) {
    setBusyId(id)
    try {
      await api(`/admin/needs/${id}/flag/`, {
        method: 'POST',
        body: JSON.stringify({ reason: 'Flag desde panel admin' }),
      })
      await load()
    } catch (e) {
      setError((e as ApiError).message)
    } finally {
      setBusyId('')
    }
  }

  async function unpublish(id: string) {
    setBusyId(id)
    try {
      await api(`/admin/needs/${id}/unpublish/`, {
        method: 'POST',
        body: JSON.stringify({ status: 'PAUSED' }),
      })
      await load()
    } catch (e) {
      setError((e as ApiError).message)
    } finally {
      setBusyId('')
    }
  }

  return (
    <div>
      <div className="dash-header">
        <div>
          <h1 className="page-title">Necesidades</h1>
          <p className="page-sub" style={{ marginBottom: 0 }}>
            Crear, editar y moderar publicaciones de compradores
          </p>
        </div>
        <button className="btn btn-primary" type="button" onClick={() => setShowCreate((v) => !v)}>
          {showCreate ? 'Cerrar formulario' : '+ Nueva necesidad'}
        </button>
      </div>

      {showCreate && (
        <form className="card" onSubmit={create} style={{ marginBottom: 18 }}>
          <h3 style={{ marginTop: 0 }}>Nueva necesidad</h3>
          <div className="toolbar" style={{ flexWrap: 'wrap' }}>
            <select
              value={createForm.buyer_id}
              onChange={(e) => setCreateForm({ ...createForm, buyer_id: e.target.value })}
              required
            >
              <option value="">Comprador (usuario)…</option>
              {users.map((u) => (
                <option key={u.id} value={u.id}>
                  {u.full_name} — {u.email}
                </option>
              ))}
            </select>
            <select
              value={createForm.asset_type}
              onChange={(e) => setCreateForm({ ...createForm, asset_type: e.target.value })}
            >
              <option value="VEHICLE">VEHICLE</option>
              <option value="PROPERTY">PROPERTY</option>
            </select>
            <input
              placeholder="Título"
              value={createForm.title}
              onChange={(e) => setCreateForm({ ...createForm, title: e.target.value })}
              required
            />
            <input
              placeholder="Presupuesto COP"
              value={createForm.budget_max_cop}
              onChange={(e) => setCreateForm({ ...createForm, budget_max_cop: e.target.value })}
              required
            />
            <input
              placeholder="Ciudad"
              value={createForm.city}
              onChange={(e) => setCreateForm({ ...createForm, city: e.target.value })}
              required
            />
            {createForm.asset_type === 'VEHICLE' ? (
              <>
                <input
                  placeholder="Marca"
                  value={createForm.brand}
                  onChange={(e) => setCreateForm({ ...createForm, brand: e.target.value })}
                />
                <input
                  placeholder="Modelo"
                  value={createForm.model}
                  onChange={(e) => setCreateForm({ ...createForm, model: e.target.value })}
                />
              </>
            ) : (
              <select
                value={createForm.property_type}
                onChange={(e) => setCreateForm({ ...createForm, property_type: e.target.value })}
              >
                <option value="APTO">APTO</option>
                <option value="CASA">CASA</option>
                <option value="LOCAL">LOCAL</option>
                <option value="LOTE_FINCA">LOTE_FINCA</option>
              </select>
            )}
            <label style={{ display: 'flex', gap: 6, alignItems: 'center' }}>
              <input
                type="checkbox"
                checked={createForm.publish}
                onChange={(e) => setCreateForm({ ...createForm, publish: e.target.checked })}
              />
              Publicar (ACTIVE)
            </label>
            <button className="btn btn-primary" type="submit" disabled={busy}>
              Crear
            </button>
          </div>
        </form>
      )}

      <div className="toolbar">
        <select value={status} onChange={(e) => setStatus(e.target.value)}>
          <option value="">Todos</option>
          <option value="ACTIVE">ACTIVE</option>
          <option value="PAUSED">PAUSED</option>
          <option value="EXPIRED">EXPIRED</option>
          <option value="FULFILLED">FULFILLED</option>
          <option value="DRAFT">DRAFT</option>
        </select>
        <button className="btn btn-navy" onClick={load}>
          Filtrar
        </button>
      </div>
      {error && <p className="error">{error}</p>}
      {msg && <p className="muted">{msg}</p>}

      {editing && (
        <form className="card" onSubmit={saveEdit} style={{ marginBottom: 18 }}>
          <h3 style={{ marginTop: 0 }}>Editar: {editing.title}</h3>
          <div className="toolbar" style={{ flexWrap: 'wrap' }}>
            <input
              placeholder="Título"
              value={form.title}
              onChange={(e) => setForm({ ...form, title: e.target.value })}
              required
              style={{ minWidth: 220 }}
            />
            <input
              placeholder="Ciudad"
              value={form.city}
              onChange={(e) => setForm({ ...form, city: e.target.value })}
            />
            <input
              placeholder="Presupuesto COP"
              value={form.budget_max_cop}
              onChange={(e) => setForm({ ...form, budget_max_cop: e.target.value })}
            />
            <select
              value={form.payment_type}
              onChange={(e) => setForm({ ...form, payment_type: e.target.value })}
            >
              <option value="CASH">CASH</option>
              <option value="TRANSFER">TRANSFER</option>
              <option value="CREDIT">CREDIT</option>
              <option value="MORTGAGE">MORTGAGE</option>
              <option value="TRADE_IN">TRADE_IN</option>
            </select>
            <select value={form.status} onChange={(e) => setForm({ ...form, status: e.target.value })}>
              <option value="DRAFT">DRAFT</option>
              <option value="ACTIVE">ACTIVE</option>
              <option value="PAUSED">PAUSED</option>
              <option value="EXPIRED">EXPIRED</option>
              <option value="FULFILLED">FULFILLED</option>
              <option value="DELETED">DELETED</option>
            </select>
          </div>
          <textarea
            placeholder="Descripción"
            value={form.description}
            onChange={(e) => setForm({ ...form, description: e.target.value })}
            rows={3}
            style={{
              width: '100%',
              marginTop: 10,
              padding: 10,
              borderRadius: 10,
              border: '1px solid var(--border)',
            }}
          />
          <div className="row-actions" style={{ marginTop: 12 }}>
            <button className="btn btn-primary" type="submit" disabled={busyId === editing.id}>
              Guardar
            </button>
            <button className="btn btn-ghost" type="button" onClick={() => setEditing(null)}>
              Cancelar
            </button>
          </div>
        </form>
      )}

      <div className="card table-wrap">
        <table className="data">
          <thead>
            <tr>
              <th>Título</th>
              <th>Tipo</th>
              <th>Ciudad</th>
              <th>Presupuesto</th>
              <th>Estado</th>
              <th>Matches</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {rows.map((n) => (
              <tr key={n.id}>
                <td>{n.title}</td>
                <td>{n.asset_type}</td>
                <td>{n.city}</td>
                <td>{n.budget_max_cop}</td>
                <td>
                  <span className="badge">{n.status}</span>
                </td>
                <td>{n.matches_count}</td>
                <td className="row-actions">
                  <button className="btn btn-navy" disabled={busyId === n.id} onClick={() => openEdit(n)}>
                    Editar
                  </button>
                  <button className="btn btn-ghost" disabled={busyId === n.id} onClick={() => flag(n.id)}>
                    Marcar
                  </button>
                  <button
                    className="btn btn-danger"
                    disabled={busyId === n.id}
                    onClick={() => unpublish(n.id)}
                  >
                    Pausar
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  )
}
