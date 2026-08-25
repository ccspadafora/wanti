import { useEffect, useState } from 'react'
import { api, qs, type ApiError, type Paginated } from '../lib/api'

type Row = {
  id: string
  action: string
  entity: string
  entity_id?: string
  actor_email?: string
  metadata?: Record<string, unknown>
  created_at: string
}

export function AuditLogsPage() {
  const [rows, setRows] = useState<Row[]>([])
  const [action, setAction] = useState('')
  const [entity, setEntity] = useState('')
  const [search, setSearch] = useState('')
  const [error, setError] = useState('')

  async function load() {
    setError('')
    try {
      const data = await api<Paginated<Row>>(
        `/admin/audit-logs/${qs({ action, entity, search })}`,
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

  return (
    <div>
      <h1 className="page-title">Auditoría</h1>
      <p className="page-sub">Registro de acciones sensibles del sistema</p>
      <div className="toolbar">
        <input placeholder="Acción" value={action} onChange={(e) => setAction(e.target.value)} />
        <input placeholder="Entidad" value={entity} onChange={(e) => setEntity(e.target.value)} />
        <input placeholder="Email actor" value={search} onChange={(e) => setSearch(e.target.value)} />
        <button className="btn btn-navy" onClick={load}>
          Filtrar
        </button>
      </div>
      {error && <p className="error">{error}</p>}
      <div className="card table-wrap">
        <table className="data">
          <thead>
            <tr>
              <th>Fecha</th>
              <th>Acción</th>
              <th>Entidad</th>
              <th>Actor</th>
              <th>Detalle</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((r) => (
              <tr key={r.id}>
                <td>{r.created_at?.slice(0, 19)}</td>
                <td>{r.action}</td>
                <td>
                  {r.entity}
                  {r.entity_id ? ` · ${r.entity_id.slice(0, 8)}` : ''}
                </td>
                <td>{r.actor_email || '—'}</td>
                <td className="muted" style={{ maxWidth: 280 }}>
                  {r.metadata ? JSON.stringify(r.metadata) : '—'}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  )
}
