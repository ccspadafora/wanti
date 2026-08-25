import { useEffect, useState, type FormEvent } from 'react'
import { api, qs, type ApiError, type Paginated } from '../lib/api'

type UserOpt = { id: string; email: string; full_name: string }

type Item = {
  id: string
  title: string
  description?: string
  asset_type: string
  city: string
  status: string
  price_cop: string | number
  unlock_count: number
}

const emptyEdit = {
  title: '',
  description: '',
  city: '',
  price_cop: '',
  status: 'AVAILABLE',
}

const emptyCreate = {
  seller_id: '',
  asset_type: 'VEHICLE',
  title: '',
  description: '',
  price_cop: '45000000',
  city: 'Bogota',
  brand: '',
  model: '',
  year: '2020',
  mileage_km: '30000',
  property_type: 'APTO',
}

export function InventoryPage() {
  const [rows, setRows] = useState<Item[]>([])
  const [users, setUsers] = useState<UserOpt[]>([])
  const [status, setStatus] = useState('')
  const [assetType, setAssetType] = useState('')
  const [error, setError] = useState('')
  const [busyId, setBusyId] = useState('')
  const [editing, setEditing] = useState<Item | null>(null)
  const [form, setForm] = useState(emptyEdit)
  const [createForm, setCreateForm] = useState(emptyCreate)
  const [showCreate, setShowCreate] = useState(false)
  const [msg, setMsg] = useState('')
  const [busy, setBusy] = useState(false)

  async function load() {
    setError('')
    try {
      const data = await api<Paginated<Item>>(
        `/admin/inventory/${qs({ status, asset_type: assetType })}`,
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

  function openEdit(i: Item) {
    setEditing(i)
    setForm({
      title: i.title || '',
      description: i.description || '',
      city: i.city || '',
      price_cop: String(i.price_cop ?? ''),
      status: i.status,
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
      await api(`/admin/inventory/${editing.id}/`, {
        method: 'PATCH',
        body: JSON.stringify({
          title: form.title,
          description: form.description,
          city: form.city,
          price_cop: form.price_cop,
          status: form.status,
        }),
      })
      setMsg('Inventario actualizado')
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
      await api('/admin/inventory/', {
        method: 'POST',
        body: JSON.stringify({
          ...createForm,
          year: Number(createForm.year),
          mileage_km: Number(createForm.mileage_km),
        }),
      })
      setMsg('Inventario creado')
      setCreateForm(emptyCreate)
      setShowCreate(false)
      await load()
    } catch (err) {
      setError((err as ApiError).message)
    } finally {
      setBusy(false)
    }
  }

  async function act(id: string, action: 'flag' | 'deactivate' | 'reactivate') {
    setBusyId(id)
    try {
      await api(`/admin/inventory/${id}/${action}/`, {
        method: 'POST',
        body: JSON.stringify({ reason: 'Moderación panel admin' }),
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
          <h1 className="page-title">Inventario</h1>
          <p className="page-sub" style={{ marginBottom: 0 }}>
            Crear, editar y moderar publicaciones de vendedores
          </p>
        </div>
        <button className="btn btn-primary" type="button" onClick={() => setShowCreate((v) => !v)}>
          {showCreate ? 'Cerrar formulario' : '+ Nuevo inventario'}
        </button>
      </div>

      {showCreate && (
        <form className="card" onSubmit={create} style={{ marginBottom: 18 }}>
          <h3 style={{ marginTop: 0 }}>Nuevo inventario</h3>
          <div className="toolbar" style={{ flexWrap: 'wrap' }}>
            <select
              value={createForm.seller_id}
              onChange={(e) => setCreateForm({ ...createForm, seller_id: e.target.value })}
              required
            >
              <option value="">Vendedor (usuario)…</option>
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
              placeholder="Precio COP"
              value={createForm.price_cop}
              onChange={(e) => setCreateForm({ ...createForm, price_cop: e.target.value })}
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
                <input
                  placeholder="Año"
                  value={createForm.year}
                  onChange={(e) => setCreateForm({ ...createForm, year: e.target.value })}
                />
                <input
                  placeholder="Km"
                  value={createForm.mileage_km}
                  onChange={(e) => setCreateForm({ ...createForm, mileage_km: e.target.value })}
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
            <button className="btn btn-primary" type="submit" disabled={busy}>
              Crear
            </button>
          </div>
        </form>
      )}

      <div className="toolbar">
        <select value={status} onChange={(e) => setStatus(e.target.value)}>
          <option value="">Todos</option>
          <option value="AVAILABLE">AVAILABLE</option>
          <option value="RESERVED">RESERVED</option>
          <option value="SOLD">SOLD</option>
          <option value="INACTIVE">INACTIVE</option>
        </select>
        <select value={assetType} onChange={(e) => setAssetType(e.target.value)}>
          <option value="">Vehículos e inmuebles</option>
          <option value="VEHICLE">VEHICLE</option>
          <option value="PROPERTY">PROPERTY</option>
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
              placeholder="Precio COP"
              value={form.price_cop}
              onChange={(e) => setForm({ ...form, price_cop: e.target.value })}
            />
            <select value={form.status} onChange={(e) => setForm({ ...form, status: e.target.value })}>
              <option value="AVAILABLE">AVAILABLE</option>
              <option value="RESERVED">RESERVED</option>
              <option value="SOLD">SOLD</option>
              <option value="INACTIVE">INACTIVE</option>
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
              <th>Precio</th>
              <th>Estado</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {rows.map((i) => (
              <tr key={i.id}>
                <td>{i.title}</td>
                <td>{i.asset_type}</td>
                <td>{i.city}</td>
                <td>{i.price_cop}</td>
                <td>
                  <span className="badge">{i.status}</span>
                </td>
                <td className="row-actions">
                  <button className="btn btn-navy" disabled={busyId === i.id} onClick={() => openEdit(i)}>
                    Editar
                  </button>
                  <button
                    className="btn btn-ghost"
                    disabled={busyId === i.id}
                    onClick={() => act(i.id, 'flag')}
                  >
                    Marcar
                  </button>
                  {i.status !== 'INACTIVE' ? (
                    <button
                      className="btn btn-danger"
                      disabled={busyId === i.id}
                      onClick={() => act(i.id, 'deactivate')}
                    >
                      Bajar
                    </button>
                  ) : (
                    <button
                      className="btn btn-primary"
                      disabled={busyId === i.id}
                      onClick={() => act(i.id, 'reactivate')}
                    >
                      Reactivar
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
