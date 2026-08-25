import { useEffect, useState } from 'react'
import { api, type ApiError } from '../lib/api'

export function ReportsPage() {
  const [interactions, setInteractions] = useState<unknown>(null)
  const [matching, setMatching] = useState<unknown>(null)
  const [error, setError] = useState('')

  useEffect(() => {
    Promise.all([
      api('/admin/reports/interactions/'),
      api('/admin/reports/matching/'),
    ])
      .then(([a, b]) => {
        setInteractions(a)
        setMatching(b)
      })
      .catch((e: ApiError) => setError(e.message))
  }, [])

  return (
    <div>
      <h1 className="page-title">Reportes</h1>
      <p className="page-sub">Interacciones y distribución de matching</p>
      {error && <p className="error">{error}</p>}
      <div className="stack">
        <div className="card">
          <h3 style={{ marginTop: 0 }}>Interacciones</h3>
          <pre style={{ margin: 0, whiteSpace: 'pre-wrap', fontSize: 13 }}>
            {interactions ? JSON.stringify(interactions, null, 2) : 'Cargando…'}
          </pre>
        </div>
        <div className="card">
          <h3 style={{ marginTop: 0 }}>Matching</h3>
          <pre style={{ margin: 0, whiteSpace: 'pre-wrap', fontSize: 13 }}>
            {matching ? JSON.stringify(matching, null, 2) : 'Cargando…'}
          </pre>
        </div>
      </div>
    </div>
  )
}
