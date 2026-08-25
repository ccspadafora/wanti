import { useEffect, useState } from 'react'
import { api, qs, type ApiError, type Paginated } from '../lib/api'

type Dispute = {
  id: string
  status: string
  reason: string
  description?: string
  created_at: string
  resolution_note?: string
}

export function DisputesPage() {
  const [rows, setRows] = useState<Dispute[]>([])
  const [status, setStatus] = useState('')
  const [error, setError] = useState('')
  const [busyId, setBusyId] = useState('')
  const [note, setNote] = useState('Revisión panel admin')

  async function load() {
    setError('')
    try {
      const data = await api<Paginated<Dispute> | Dispute[]>(
        `/admin/disputes/${qs({ status })}`,
      )
      setRows(Array.isArray(data) ? data : data.results || [])
    } catch (e) {
      setError((e as ApiError).message)
    }
  }

  useEffect(() => {
    load()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  async function act(id: string, action: 'approve' | 'reject') {
    setBusyId(id)
    try {
      await api(`/admin/disputes/${id}/${action}/`, {
        method: 'POST',
        body: JSON.stringify({ note }),
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
      <h1 className="page-title">Disputas</h1>
      <p className="page-sub">Aprobar o rechazar reclamos de contacto</p>
      <div className="toolbar">
        <select value={status} onChange={(e) => setStatus(e.target.value)}>
          <option value="">Todas</option>
          <option value="OPEN">OPEN</option>
          <option value="AUTO_REVIEW">AUTO_REVIEW</option>
          <option value="HUMAN_REVIEW">HUMAN_REVIEW</option>
          <option value="RESOLVED_REFUND">RESOLVED_REFUND</option>
          <option value="RESOLVED_REJECTED">RESOLVED_REJECTED</option>
        </select>
        <input value={note} onChange={(e) => setNote(e.target.value)} placeholder="Nota" />
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
              <th>Creada</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {rows.map((d) => (
              <tr key={d.id}>
                <td>
                  <div>{d.reason}</div>
                  {d.description && <div className="muted">{d.description}</div>}
                </td>
                <td>
                  <span className="badge">{d.status}</span>
                </td>
                <td>{d.created_at?.slice(0, 10)}</td>
                <td className="row-actions">
                  <button
                    className="btn btn-primary"
                    disabled={busyId === d.id}
                    onClick={() => act(d.id, 'approve')}
                  >
                    Aprobar
                  </button>
                  <button
                    className="btn btn-danger"
                    disabled={busyId === d.id}
                    onClick={() => act(d.id, 'reject')}
                  >
                    Rechazar
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
