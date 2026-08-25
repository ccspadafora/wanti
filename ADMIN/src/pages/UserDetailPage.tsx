import { useEffect, useState, type FormEvent } from 'react'
import { Link, useParams } from 'react-router-dom'
import { api, type ApiError, type Paginated } from '../lib/api'
import { useAuth } from '../lib/auth'

type UserDetail = {
  id: string
  email: string
  full_name: string
  phone: string
  city: string
  role: string
  status: string
  email_verified_at?: string | null
  phone_verified_at?: string | null
  wallet_balance?: number
  disputes_count?: number
  rating_average?: number
}

type Txn = {
  id: string
  transaction_type: string
  amount_wantis: number
  balance_after: number
  note: string
  created_at: string
}

export function UserDetailPage() {
  const { id = '' } = useParams()
  const { user: me } = useAuth()
  const [user, setUser] = useState<UserDetail | null>(null)
  const [txns, setTxns] = useState<Txn[]>([])
  const [error, setError] = useState('')
  const [reason, setReason] = useState('')
  const [amount, setAmount] = useState('1')
  const [note, setNote] = useState('')
  const [role, setRole] = useState('USER')
  const [busy, setBusy] = useState(false)
  const [edit, setEdit] = useState({
    full_name: '',
    phone: '',
    city: '',
    status: '',
  })
  const [saveMsg, setSaveMsg] = useState('')

  async function load() {
    setError('')
    try {
      const u = await api<UserDetail>(`/admin/users/${id}/`)
      setUser(u)
      setRole(u.role)
      setEdit({
        full_name: u.full_name || '',
        phone: u.phone || '',
        city: u.city || '',
        status: u.status || '',
      })
      const ledger = await api<Paginated<Txn>>(`/admin/wallets/${id}/transactions/`)
      setTxns(ledger.results || [])
    } catch (e) {
      setError((e as ApiError).message)
    }
  }

  useEffect(() => {
    load()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [id])

  async function suspend() {
    if (!reason.trim()) {
      setError('Indicá un motivo de suspensión')
      return
    }
    setBusy(true)
    try {
      await api(`/admin/users/${id}/suspend/`, {
        method: 'POST',
        body: JSON.stringify({ reason }),
      })
      await load()
    } catch (e) {
      setError((e as ApiError).message)
    } finally {
      setBusy(false)
    }
  }

  async function activate() {
    setBusy(true)
    try {
      await api(`/admin/users/${id}/activate/`, { method: 'POST' })
      await load()
    } catch (e) {
      setError((e as ApiError).message)
    } finally {
      setBusy(false)
    }
  }

  async function verify(email: boolean, phone: boolean) {
    setBusy(true)
    try {
      await api(`/admin/users/${id}/verify/`, {
        method: 'POST',
        body: JSON.stringify({ email, phone }),
      })
      await load()
    } catch (e) {
      setError((e as ApiError).message)
    } finally {
      setBusy(false)
    }
  }

  async function setUserRole() {
    setBusy(true)
    try {
      await api(`/admin/users/${id}/set-role/`, {
        method: 'POST',
        body: JSON.stringify({ role }),
      })
      await load()
    } catch (e) {
      setError((e as ApiError).message)
    } finally {
      setBusy(false)
    }
  }

  async function adjustWallet(e: FormEvent) {
    e.preventDefault()
    setBusy(true)
    setError('')
    try {
      await api(`/admin/wallets/${id}/adjust/`, {
        method: 'POST',
        body: JSON.stringify({
          amount_wantis: Number(amount),
          note: note || 'Ajuste manual admin',
        }),
      })
      setNote('')
      await load()
    } catch (err) {
      setError((err as ApiError).message)
    } finally {
      setBusy(false)
    }
  }

  async function saveProfile(e: FormEvent) {
    e.preventDefault()
    setBusy(true)
    setError('')
    setSaveMsg('')
    try {
      await api(`/admin/users/${id}/`, {
        method: 'PATCH',
        body: JSON.stringify({
          full_name: edit.full_name,
          phone: edit.phone,
          city: edit.city,
          status: edit.status,
        }),
      })
      setSaveMsg('Perfil actualizado')
      await load()
    } catch (err) {
      setError((err as ApiError).message)
    } finally {
      setBusy(false)
    }
  }

  if (!user && !error) return <p className="muted">Cargando…</p>

  return (
    <div>
      <p>
        <Link to="/users">← Usuarios</Link>
      </p>
      <h1 className="page-title">{user?.full_name || 'Usuario'}</h1>
      <p className="page-sub">{user?.email}</p>
      {error && <p className="error">{error}</p>}
      {saveMsg && <p className="muted">{saveMsg}</p>}
      {user && (
        <div className="stack">
          <form className="card" onSubmit={saveProfile}>
            <h3 style={{ marginTop: 0 }}>Editar perfil</h3>
            <div className="toolbar" style={{ flexWrap: 'wrap' }}>
              <input
                placeholder="Nombre"
                value={edit.full_name}
                onChange={(e) => setEdit({ ...edit, full_name: e.target.value })}
                required
              />
              <input
                placeholder="Teléfono"
                value={edit.phone}
                onChange={(e) => setEdit({ ...edit, phone: e.target.value })}
              />
              <input
                placeholder="Ciudad"
                value={edit.city}
                onChange={(e) => setEdit({ ...edit, city: e.target.value })}
              />
              <select
                value={edit.status}
                onChange={(e) => setEdit({ ...edit, status: e.target.value })}
              >
                <option value="PENDING">PENDING</option>
                <option value="ACTIVE">ACTIVE</option>
                <option value="SUSPENDED">SUSPENDED</option>
              </select>
              <button className="btn btn-primary" disabled={busy} type="submit">
                Guardar cambios
              </button>
            </div>
            <p className="muted" style={{ marginBottom: 0 }}>
              Email: {user.email} · Wallet: {user.wallet_balance ?? 0} Wanti · Rating:{' '}
              {user.rating_average ?? '—'}
            </p>
          </form>

          <div className="card">
            <p>
              <strong>Email verificado:</strong> {user.email_verified_at ? 'Sí' : 'No'} ·{' '}
              <strong>Tel verificado:</strong> {user.phone_verified_at ? 'Sí' : 'No'}
            </p>
            <div className="row-actions" style={{ marginTop: 12 }}>
              <button className="btn btn-primary" disabled={busy} onClick={() => verify(true, true)}>
                Verificar email + tel
              </button>
              <button className="btn btn-ghost" disabled={busy} onClick={() => verify(true, false)}>
                Solo email
              </button>
              <button className="btn btn-ghost" disabled={busy} onClick={() => verify(false, true)}>
                Solo tel
              </button>
            </div>
            <div className="row-actions" style={{ marginTop: 12 }}>
              {user.status !== 'SUSPENDED' ? (
                <>
                  <input
                    placeholder="Motivo suspensión"
                    value={reason}
                    onChange={(e) => setReason(e.target.value)}
                    style={{
                      minWidth: 220,
                      padding: '9px 12px',
                      borderRadius: 10,
                      border: '1px solid var(--border)',
                    }}
                  />
                  <button className="btn btn-danger" disabled={busy} onClick={suspend}>
                    Suspender
                  </button>
                </>
              ) : (
                <button className="btn btn-primary" disabled={busy} onClick={activate}>
                  Activar
                </button>
              )}
            </div>
          </div>

          {me?.role === 'ADMIN' && (
            <>
              <div className="card">
                <h3 style={{ marginTop: 0 }}>Cambiar rol</h3>
                <div className="toolbar">
                  <select value={role} onChange={(e) => setRole(e.target.value)}>
                    <option value="USER">USER</option>
                    <option value="MODERATOR">MODERATOR</option>
                    <option value="ADMIN">ADMIN</option>
                  </select>
                  <button className="btn btn-navy" disabled={busy} onClick={setUserRole}>
                    Guardar rol
                  </button>
                </div>
              </div>
              <form className="card" onSubmit={adjustWallet}>
                <h3 style={{ marginTop: 0 }}>Ajustar Wanti</h3>
                <div className="toolbar">
                  <input
                    type="number"
                    value={amount}
                    onChange={(e) => setAmount(e.target.value)}
                    step="1"
                  />
                  <input
                    placeholder="Nota"
                    value={note}
                    onChange={(e) => setNote(e.target.value)}
                  />
                  <button className="btn btn-navy" disabled={busy} type="submit">
                    Aplicar
                  </button>
                </div>
              </form>
            </>
          )}

          <div className="card table-wrap">
            <h3 style={{ marginTop: 0 }}>Movimientos de wallet</h3>
            <table className="data">
              <thead>
                <tr>
                  <th>Tipo</th>
                  <th>Monto</th>
                  <th>Saldo</th>
                  <th>Nota</th>
                  <th>Fecha</th>
                </tr>
              </thead>
              <tbody>
                {txns.map((t) => (
                  <tr key={t.id}>
                    <td>{t.transaction_type}</td>
                    <td>{t.amount_wantis}</td>
                    <td>{t.balance_after}</td>
                    <td className="muted">{t.note}</td>
                    <td>{t.created_at?.slice(0, 19)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  )
}
