import { useEffect, useState } from 'react'
import { api, qs, type ApiError, type Paginated } from '../lib/api'

type Row = {
  id: string
  buyer: string
  seller: string
  wantis_charged: number
  outcome: string
  created_at: string
}

export function UnlocksPage() {
  const [rows, setRows] = useState<Row[]>([])
  const [outcome, setOutcome] = useState('')
  const [error, setError] = useState('')

  async function load() {
    setError('')
    try {
      const data = await api<Paginated<Row>>(
        `/admin/contact-unlocks/${qs({ outcome })}`,
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
      <h1 className="page-title">Desbloqueos</h1>
      <p className="page-sub">
        Unlocks generados al gastar Wanti (no se crean a mano; acreditar Wanti en el detalle del usuario)
      </p>
      <div className="toolbar">
        <select value={outcome} onChange={(e) => setOutcome(e.target.value)}>
          <option value="">Todos</option>
          <option value="PENDING">PENDING</option>
          <option value="PURCHASED">PURCHASED</option>
          <option value="IN_PROGRESS">IN_PROGRESS</option>
          <option value="NOT_PURCHASED">NOT_PURCHASED</option>
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
              <th>Wanti</th>
              <th>Outcome</th>
              <th>Buyer</th>
              <th>Seller</th>
              <th>Fecha</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((r) => (
              <tr key={r.id}>
                <td>{r.wantis_charged}</td>
                <td>
                  <span className="badge">{r.outcome}</span>
                </td>
                <td className="muted">{String(r.buyer).slice(0, 8)}</td>
                <td className="muted">{String(r.seller).slice(0, 8)}</td>
                <td>{r.created_at?.slice(0, 19)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  )
}
