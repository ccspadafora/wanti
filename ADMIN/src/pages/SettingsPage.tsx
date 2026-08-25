import { useEffect, useMemo, useState, type FormEvent } from 'react'
import { api, type ApiError } from '../lib/api'
import { useAuth } from '../lib/auth'

type Setting = {
  key: string
  value: unknown
  value_type: string
  description?: string
  updated_at?: string
}

const GROUPS: { title: string; keys: string[] }[] = [
  {
    title: 'Pricing / Wanti',
    keys: ['WANTI_PRICE_COP', 'UNLOCK_COST_WANTIS'],
  },
  {
    title: 'Matching',
    keys: [
      'MATCH_MIN_SCORE',
      'MATCH_HIGH_THRESHOLD',
      'MATCH_RADIUS_KM',
      'MIN_BUDGET_RATIO',
    ],
  },
  {
    title: 'Disputas / Leads',
    keys: ['DISPUTE_AUTO_REVIEW_HOURS', 'DISPUTE_APPEAL_HOURS', 'LEAD_EXPIRY_DAYS'],
  },
  {
    title: 'Auth / OTP',
    keys: ['OTP_TTL_MINUTES', 'OTP_MAX_ATTEMPTS', 'NEED_DEFAULT_DAYS'],
  },
]

function groupFor(key: string) {
  return GROUPS.find((g) => g.keys.includes(key))?.title || 'Otros'
}

export function SettingsPage() {
  const { user } = useAuth()
  const [rows, setRows] = useState<Setting[]>([])
  const [drafts, setDrafts] = useState<Record<string, string>>({})
  const [error, setError] = useState('')
  const [msg, setMsg] = useState('')
  const [newKey, setNewKey] = useState('')
  const [newValue, setNewValue] = useState('')
  const isAdmin = user?.role === 'ADMIN'

  async function load() {
    setError('')
    try {
      const data = await api<Setting[]>('/admin/settings/')
      const list = Array.isArray(data) ? data : []
      setRows(list)
      const d: Record<string, string> = {}
      list.forEach((s) => {
        d[s.key] = typeof s.value === 'string' ? s.value : JSON.stringify(s.value)
      })
      setDrafts(d)
    } catch (e) {
      setError((e as ApiError).message)
    }
  }

  useEffect(() => {
    load()
  }, [])

  const grouped = useMemo(() => {
    const map = new Map<string, Setting[]>()
    rows.forEach((s) => {
      const g = groupFor(s.key)
      if (!map.has(g)) map.set(g, [])
      map.get(g)!.push(s)
    })
    return map
  }, [rows])

  async function save(key: string) {
    if (!isAdmin) return
    setError('')
    setMsg('')
    try {
      await api(`/admin/settings/${key}/`, {
        method: 'PATCH',
        body: JSON.stringify({ value: drafts[key] }),
      })
      setMsg(`Guardado: ${key}`)
      await load()
    } catch (e) {
      setError((e as ApiError).message)
    }
  }

  async function createSetting(e: FormEvent) {
    e.preventDefault()
    if (!isAdmin) return
    try {
      await api('/admin/settings/', {
        method: 'POST',
        body: JSON.stringify({
          key: newKey.trim(),
          value: newValue,
          value_type: 'STRING',
        }),
      })
      setNewKey('')
      setNewValue('')
      setMsg('Setting creado')
      await load()
    } catch (err) {
      setError((err as ApiError).message)
    }
  }

  return (
    <div>
      <h1 className="page-title">Settings</h1>
      <p className="page-sub">
        Precio del Wanti, matching y reglas de negocio{' '}
        {isAdmin ? '(editable)' : '(solo lectura para MODERATOR)'}
      </p>
      {error && <p className="error">{error}</p>}
      {msg && <p className="muted">{msg}</p>}

      {[...grouped.entries()].map(([title, items]) => (
        <div key={title} style={{ marginBottom: 22 }}>
          <h2 style={{ fontSize: '1.05rem', marginBottom: 10 }}>{title}</h2>
          <div className="stack">
            {items.map((s) => (
              <div className="card" key={s.key}>
                <strong>{s.key}</strong>
                {s.description && <p className="muted">{s.description}</p>}
                <div className="toolbar">
                  <input
                    style={{ flex: 1, minWidth: 240 }}
                    value={drafts[s.key] ?? ''}
                    disabled={!isAdmin}
                    onChange={(e) => setDrafts((d) => ({ ...d, [s.key]: e.target.value }))}
                  />
                  {isAdmin && (
                    <button className="btn btn-navy" onClick={() => save(s.key)}>
                      Guardar
                    </button>
                  )}
                </div>
              </div>
            ))}
          </div>
        </div>
      ))}

      {isAdmin && (
        <form className="card" onSubmit={createSetting}>
          <h3 style={{ marginTop: 0 }}>Crear setting</h3>
          <div className="toolbar">
            <input
              placeholder="KEY"
              value={newKey}
              onChange={(e) => setNewKey(e.target.value)}
              required
            />
            <input
              placeholder="Valor"
              value={newValue}
              onChange={(e) => setNewValue(e.target.value)}
              required
            />
            <button className="btn btn-primary" type="submit">
              Crear
            </button>
          </div>
        </form>
      )}
    </div>
  )
}
