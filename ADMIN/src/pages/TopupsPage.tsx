import { useEffect, useState } from 'react'
import { api, qs, type ApiError, type Paginated } from '../lib/api'
import { useAuth } from '../lib/auth'

type Topup = {
  id: string
  wantis_total: number
  price_cop: string | number
  status: string
  provider_reference?: string
  user_email?: string
  package_name?: string
  created_at: string
}

export function TopupsPage() {
  const { user } = useAuth()
  const [rows, setRows] = useState<Topup[]>([])
  const [status, setStatus] = useState('')
  const [error, setError] = useState('')
  const [busyId, setBusyId] = useState('')

  async function load() {
    setError('')
    try {
      const data = await api<Paginated<Topup>>(`/admin/topups/${qs({ status })}`)
      setRows(data.results || [])
    } catch (e) {
      setError((e as ApiError).message)
    }
  }

  useEffect(() => {
    load()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  async function fail(id: string) {
    setBusyId(id)
    try {
      await api(`/admin/topups/${id}/fail/`, { method: 'POST' })
      await load()
    } catch (e) {
      setError((e as ApiError).message)
    } finally {
      setBusyId('')
    }
  }

  async function complete(id: string) {
    setBusyId(id)
    try {
      await api(`/admin/topups/${id}/complete/`, { method: 'POST' })
      await load()
    } catch (e) {
      setError((e as ApiError).message)
    } finally {
      setBusyId('')
    }
  }

  return (
    <div>
      <h1 className="page-title">Órdenes de recarga</h1>
      <p className="page-sub">
        Completar o descartar órdenes · para acreditar Wanti manualmente usá el detalle del usuario
      </p>
      <p className="page-sub">Recargas de Wanti · completar o fallar manualmente</p>
      <div className="toolbar">
        <select value={status} onChange={(e) => setStatus(e.target.value)}>
          <option value="">Todas</option>
          <option value="PENDING">PENDING</option>
          <option value="COMPLETED">COMPLETED</option>
          <option value="FAILED">FAILED</option>
        </select>
        <button className="btn btn-navy" onClick={load}>
          Filtrar
        </button>
      </div>
      {error && <p className="error">{error}</p>}
      <div className="card table-wrap">
        <table className="data">
          <thead>
            <tr>
              <th>Usuario</th>
              <th>Paquete</th>
              <th>Wanti</th>
              <th>Precio</th>
              <th>Estado</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {rows.map((t) => (
              <tr key={t.id}>
                <td>{t.user_email || '—'}</td>
                <td>{t.package_name || '—'}</td>
                <td>{t.wantis_total}</td>
                <td>{t.price_cop}</td>
                <td>
                  <span className={`badge ${t.status === 'COMPLETED' ? 'ok' : t.status === 'FAILED' ? 'danger' : 'warn'}`}>
                    {t.status}
                  </span>
                </td>
                <td className="row-actions">
                  {t.status === 'PENDING' && (
                    <>
                      <button
                        className="btn btn-danger"
                        disabled={busyId === t.id}
                        onClick={() => fail(t.id)}
                      >
                        Descartar
                      </button>
                      {user?.role === 'ADMIN' && (
                        <button
                          className="btn btn-primary"
                          disabled={busyId === t.id}
                          onClick={() => complete(t.id)}
                        >
                          Completar
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
