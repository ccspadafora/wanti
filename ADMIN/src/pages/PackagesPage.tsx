import { useEffect, useState, type FormEvent } from 'react'
import { api, type ApiError } from '../lib/api'
import { useAuth } from '../lib/auth'

type Package = {
  id: string
  name: string
  wantis_base: number
  wantis_bonus: number
  wantis_total: number
  price_cop: string | number
  is_popular: boolean
  is_active: boolean
  order: number
}

const emptyForm = {
  name: '',
  wantis_base: '5',
  wantis_bonus: '0',
  price_cop: '25000',
  is_popular: false,
  is_active: true,
  order: '0',
}

export function PackagesPage() {
  const { user } = useAuth()
  const isAdmin = user?.role === 'ADMIN'
  const [rows, setRows] = useState<Package[]>([])
  const [form, setForm] = useState(emptyForm)
  const [editingId, setEditingId] = useState<string | null>(null)
  const [error, setError] = useState('')
  const [msg, setMsg] = useState('')

  async function load() {
    setError('')
    try {
      const data = await api<Package[]>('/admin/packages/')
      setRows(Array.isArray(data) ? data : [])
    } catch (e) {
      setError((e as ApiError).message)
    }
  }

  useEffect(() => {
    load()
  }, [])

  function startEdit(p: Package) {
    setEditingId(p.id)
    setForm({
      name: p.name,
      wantis_base: String(p.wantis_base),
      wantis_bonus: String(p.wantis_bonus),
      price_cop: String(p.price_cop),
      is_popular: p.is_popular,
      is_active: p.is_active,
      order: String(p.order),
    })
    setMsg('')
  }

  async function create(e: FormEvent) {
    e.preventDefault()
    if (!isAdmin) return
    setError('')
    setMsg('')
    try {
      const payload = {
        name: form.name,
        wantis_base: Number(form.wantis_base),
        wantis_bonus: Number(form.wantis_bonus),
        price_cop: form.price_cop,
        is_popular: form.is_popular,
        is_active: form.is_active,
        order: Number(form.order),
      }
      if (editingId) {
        await api(`/admin/packages/${editingId}/`, {
          method: 'PATCH',
          body: JSON.stringify(payload),
        })
        setMsg('Paquete actualizado')
      } else {
        await api('/admin/packages/', {
          method: 'POST',
          body: JSON.stringify(payload),
        })
        setMsg('Paquete creado')
      }
      setForm(emptyForm)
      setEditingId(null)
      await load()
    } catch (err) {
      setError((err as ApiError).message)
    }
  }

  async function toggleActive(p: Package) {
    if (!isAdmin) return
    try {
      await api(`/admin/packages/${p.id}/`, {
        method: 'PATCH',
        body: JSON.stringify({ is_active: !p.is_active }),
      })
      await load()
    } catch (e) {
      setError((e as ApiError).message)
    }
  }

  async function deactivate(p: Package) {
    if (!isAdmin) return
    try {
      await api(`/admin/packages/${p.id}/`, { method: 'DELETE' })
      await load()
    } catch (e) {
      setError((e as ApiError).message)
    }
  }

  return (
    <div>
      <h1 className="page-title">Paquetes Wanti</h1>
      <p className="page-sub">Catálogo de recarga que ve la app · solo ADMIN escribe</p>
      {error && <p className="error">{error}</p>}
      {msg && <p className="muted">{msg}</p>}

      {isAdmin && (
        <form className="card" onSubmit={create} style={{ marginBottom: 18 }}>
          <h3 style={{ marginTop: 0 }}>{editingId ? 'Editar paquete' : 'Nuevo paquete'}</h3>
          <div className="toolbar">
            <input
              placeholder="Nombre"
              value={form.name}
              onChange={(e) => setForm({ ...form, name: e.target.value })}
              required
            />
            <input
              placeholder="Wanti base"
              value={form.wantis_base}
              onChange={(e) => setForm({ ...form, wantis_base: e.target.value })}
            />
            <input
              placeholder="Bonus"
              value={form.wantis_bonus}
              onChange={(e) => setForm({ ...form, wantis_bonus: e.target.value })}
            />
            <input
              placeholder="Precio COP"
              value={form.price_cop}
              onChange={(e) => setForm({ ...form, price_cop: e.target.value })}
            />
            <label style={{ display: 'flex', gap: 6, alignItems: 'center' }}>
              <input
                type="checkbox"
                checked={form.is_popular}
                onChange={(e) => setForm({ ...form, is_popular: e.target.checked })}
              />
              Popular
            </label>
            <button className="btn btn-primary" type="submit">
              {editingId ? 'Guardar' : 'Crear'}
            </button>
            {editingId && (
              <button
                className="btn btn-ghost"
                type="button"
                onClick={() => {
                  setEditingId(null)
                  setForm(emptyForm)
                }}
              >
                Cancelar
              </button>
            )}
          </div>
        </form>
      )}

      <div className="card table-wrap">
        <table className="data">
          <thead>
            <tr>
              <th>Nombre</th>
              <th>Wanti</th>
              <th>Precio</th>
              <th>Estado</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {rows.map((p) => (
              <tr key={p.id}>
                <td>
                  {p.name} {p.is_popular ? <span className="badge warn">Popular</span> : null}
                </td>
                <td>
                  {p.wantis_base}
                  {p.wantis_bonus > 0 ? ` +${p.wantis_bonus}` : ''} = {p.wantis_total}
                </td>
                <td>{p.price_cop}</td>
                <td>
                  <span className={`badge ${p.is_active ? 'ok' : 'danger'}`}>
                    {p.is_active ? 'Activo' : 'Inactivo'}
                  </span>
                </td>
                <td className="row-actions">
                  {isAdmin && (
                    <>
                      <button className="btn btn-navy" onClick={() => startEdit(p)}>
                        Editar
                      </button>
                      <button className="btn btn-ghost" onClick={() => toggleActive(p)}>
                        {p.is_active ? 'Desactivar' : 'Activar'}
                      </button>
                      {p.is_active && (
                        <button className="btn btn-danger" onClick={() => deactivate(p)}>
                          Baja
                        </button>
                      )}
                    </>
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
