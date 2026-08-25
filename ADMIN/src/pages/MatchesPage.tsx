import { useEffect, useState } from 'react'
import { api, qs, type ApiError, type Paginated } from '../lib/api'

type Row = {
  id: string
  score: number
  status: string
  buyer: string
  seller: string
  created_at: string
}

export function MatchesPage() {
  const [rows, setRows] = useState<Row[]>([])
  const [status, setStatus] = useState('')
  const [minScore, setMinScore] = useState('')
  const [error, setError] = useState('')

  async function load() {
    setError('')
    try {
      const data = await api<Paginated<Row>>(
        `/admin/matches/${qs({ status, min_score: minScore })}`,
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
      <h1 className="page-title">Matches</h1>
      <p className="page-sub">
        Coincidencias generadas automáticamente por el motor (no se crean a mano)
      </p>
      <div className="toolbar">
        <select value={status} onChange={(e) => setStatus(e.target.value)}>
          <option value="">Todos</option>
          <option value="GENERATED">GENERATED</option>
          <option value="VIEWED">VIEWED</option>
          <option value="UNLOCKED">UNLOCKED</option>
          <option value="DISCARDED">DISCARDED</option>
        </select>
        <input
          placeholder="Score mínimo"
          value={minScore}
          onChange={(e) => setMinScore(e.target.value)}
        />
        <button className="btn btn-navy" onClick={load}>
          Filtrar
        </button>
      </div>
      {error && <p className="error">{error}</p>}
      <div className="card table-wrap">
        <table className="data">
          <thead>
            <tr>
              <th>Score</th>
              <th>Estado</th>
              <th>Buyer</th>
              <th>Seller</th>
              <th>Fecha</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((r) => (
              <tr key={r.id}>
                <td>{r.score}</td>
                <td>
                  <span className="badge">{r.status}</span>
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
