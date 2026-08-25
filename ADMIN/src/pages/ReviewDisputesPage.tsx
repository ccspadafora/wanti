import { useEffect, useState } from 'react'
import { api, qs, type ApiError, type Paginated } from '../lib/api'

type ReviewDispute = {
  id: string
  reason: string
  status: string
  admin_note?: string
  created_at: string
}

export function ReviewDisputesPage() {
  const [rows, setRows] = useState<ReviewDispute[]>([])
  const [status, setStatus] = useState('')
  const [error, setError] = useState('')
  const [busyId, setBusyId] = useState('')

  async function load() {
    setError('')
    try {
      const data = await api<Paginated<ReviewDispute>>(
        `/admin/review-disputes/${qs({ status })}`,
      )
      setRows(data.results || [])
    } catch (e) {
      setError((e as ApiError).message)
    }
  }

  useEffect(() => {
    load()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  async function resolve(id: string, keep: boolean) {
    setBusyId(id)
    try {
      await api(`/admin/review-disputes/${id}/resolve/`, {
        method: 'POST',
        body: JSON.stringify({
          keep,
          note: keep ? 'Se mantiene la reseña' : 'Se retira la reseña',
        }),
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
      <h1 className="page-title">Disputas de reseñas</h1>
      <p className="page-sub">Resolver reclamos sobre calificaciones</p>
      <div className="toolbar">
        <select value={status} onChange={(e) => setStatus(e.target.value)}>
          <option value="">Abiertas / pendientes</option>
          <option value="OPEN">OPEN</option>
          <option value="RESOLVED">RESOLVED</option>
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
              <th>Motivo</th>
              <th>Estado</th>
              <th>Fecha</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {rows.map((d) => (
              <tr key={d.id}>
                <td>{d.reason}</td>
                <td>
                  <span className="badge">{d.status}</span>
                </td>
                <td>{d.created_at?.slice(0, 10)}</td>
                <td className="row-actions">
                  <button
                    className="btn btn-primary"
                    disabled={busyId === d.id}
                    onClick={() => resolve(d.id, true)}
                  >
                    Mantener
                  </button>
                  <button
                    className="btn btn-danger"
                    disabled={busyId === d.id}
                    onClick={() => resolve(d.id, false)}
                  >
                    Retirar
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
