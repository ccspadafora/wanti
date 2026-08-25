import { useEffect, useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import { api, type ApiError, type Paginated } from '../lib/api'

type DayCount = { date: string; count: number }

type Metrics = {
  users?: Record<string, number>
  needs?: Record<string, number>
  inventory?: Record<string, number>
  matches?: Record<string, number | string>
  contacts?: Record<string, number>
  wallet?: Record<string, number | string>
  disputes?: Record<string, number>
  reviews?: Record<string, number>
  alerts?: Record<string, number>
  trends_last_7_days?: {
    new_users?: DayCount[]
    new_needs?: DayCount[]
    new_unlocks?: DayCount[]
    new_matches?: DayCount[]
  }
}

type Interactions = {
  totals?: Record<string, number>
  conversion_funnel?: Record<string, string>
}

type Matching = {
  match_distribution?: Record<string, number>
}

type AuditRow = {
  id: string
  action: string
  entity: string
  entity_id?: string | null
  created_at: string
  actor_user?: string | null
}

type UnlockRow = {
  id: string
  buyer?: string
  seller?: string
  wantis_charged?: number
  outcome?: string
  created_at: string
}

const ALERT_META: Record<string, { label: string; to: string; tone: string }> = {
  users_pending_verification: {
    label: 'Usuarios sin verificar',
    to: '/users',
    tone: 'warn',
  },
  disputes_needing_attention: {
    label: 'Disputas por atender',
    to: '/disputes',
    tone: 'danger',
  },
  review_disputes_open: {
    label: 'Impugnaciones de reseña',
    to: '/review-disputes',
    tone: 'warn',
  },
  topups_pending: { label: 'Top-ups pendientes', to: '/topups', tone: 'teal' },
  needs_paused: { label: 'Necesidades pausadas', to: '/needs', tone: 'navy' },
  inventory_inactive: {
    label: 'Inventario inactivo',
    to: '/inventory',
    tone: 'navy',
  },
}

function money(value: number | string | undefined) {
  const n = Number(value || 0)
  if (Number.isNaN(n)) return String(value ?? '—')
  return new Intl.NumberFormat('es-CO', {
    style: 'currency',
    currency: 'COP',
    maximumFractionDigits: 0,
  }).format(n)
}

function pct(value: number | string | undefined) {
  const n = Number(value || 0)
  if (Number.isNaN(n)) return '—'
  const v = n <= 1 ? n * 100 : n
  return `${v.toFixed(1)}%`
}

function Sparkline({ data }: { data?: DayCount[] }) {
  if (!data?.length) return null
  const max = Math.max(...data.map((d) => d.count), 1)
  return (
    <div className="dash-spark">
      {data.map((d) => (
        <span
          key={d.date}
          title={`${d.date}: ${d.count}`}
          style={{ height: `${Math.max(12, (d.count / max) * 100)}%` }}
        />
      ))}
    </div>
  )
}

function PipelineBar({
  segments,
}: {
  segments: { key: string; label: string; value: number; color: string }[]
}) {
  const total = segments.reduce((s, x) => s + x.value, 0) || 1
  return (
    <div className="dash-pipeline-bar">
      {segments.map((s) => (
        <div
          key={s.key}
          style={{
            width: `${(s.value / total) * 100}%`,
            background: s.color,
            minWidth: s.value ? 8 : 0,
          }}
          title={`${s.label}: ${s.value}`}
        />
      ))}
    </div>
  )
}

export function DashboardPage() {
  const [metrics, setMetrics] = useState<Metrics | null>(null)
  const [interactions, setInteractions] = useState<Interactions | null>(null)
  const [matching, setMatching] = useState<Matching | null>(null)
  const [activity, setActivity] = useState<AuditRow[]>([])
  const [unlocks, setUnlocks] = useState<UnlockRow[]>([])
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    setLoading(true)
    Promise.all([
      api<Metrics>('/admin/metrics/'),
      api<Interactions>('/admin/reports/interactions/'),
      api<Matching>('/admin/reports/matching/'),
      api<Paginated<AuditRow>>('/admin/audit-logs/?page_size=8').catch(() => ({
        results: [] as AuditRow[],
      })),
      api<Paginated<UnlockRow>>('/admin/contact-unlocks/?page_size=6').catch(() => ({
        results: [] as UnlockRow[],
      })),
    ])
      .then(([m, i, match, audit, unlockData]) => {
        setMetrics(m)
        setInteractions(i)
        setMatching(match)
        setActivity(audit.results || [])
        setUnlocks(unlockData.results || [])
      })
      .catch((e: ApiError) => setError(e.message))
      .finally(() => setLoading(false))
  }, [])

  const needStages = useMemo(() => {
    const n = metrics?.needs || {}
    return [
      { key: 'active', label: 'Activas', value: Number(n.active || 0), color: '#00B2A9' },
      { key: 'paused', label: 'Pausadas', value: Number(n.paused || 0), color: '#EF9F27' },
      { key: 'expired', label: 'Expiradas', value: Number(n.expired || 0), color: '#94A3B8' },
      {
        key: 'fulfilled',
        label: 'Cumplidas',
        value: Number(n.fulfilled || 0),
        color: '#0A1F44',
      },
    ]
  }, [metrics])

  const inventoryStages = useMemo(() => {
    const inv = metrics?.inventory || {}
    return [
      {
        key: 'available',
        label: 'Disponible',
        value: Number(inv.available || 0),
        color: '#00B2A9',
      },
      {
        key: 'sold',
        label: 'Vendido',
        value: Number(inv.sold || 0),
        color: '#007A72',
      },
      {
        key: 'inactive',
        label: 'Inactivo',
        value: Number(inv.inactive || 0),
        color: '#94A3B8',
      },
    ]
  }, [metrics])

  const alerts = metrics?.alerts
    ? Object.entries(metrics.alerts).filter(([, v]) => Number(v) > 0)
    : []

  const funnel = interactions?.conversion_funnel || {}
  const dist = matching?.match_distribution || {}

  return (
    <div className="dash">
      <header className="dash-header">
        <div>
          <h1 className="page-title">Dashboard CRM</h1>
          <p className="page-sub" style={{ marginBottom: 0 }}>
            Vista operativa de usuarios, matching, monetización y moderación
          </p>
        </div>
        <div className="dash-header-actions">
          <Link className="btn btn-ghost" to="/reports">
            Reportes
          </Link>
          <Link className="btn btn-navy" to="/disputes">
            Revisar disputas
          </Link>
        </div>
      </header>

      {error && <p className="error">{error}</p>}
      {loading && !metrics && <p className="muted">Cargando métricas…</p>}

      {metrics && (
        <>
          <section className="dash-kpi-row">
            <article className="dash-kpi featured">
              <span className="dash-kpi-label">Wanti en circulación</span>
              <strong className="dash-kpi-value">
                {metrics.wallet?.total_wantis_in_circulation ?? 0}
              </strong>
              <div className="dash-kpi-meta">
                <span>{money(metrics.wallet?.total_topup_cop_last_30_days)} recargados (30d)</span>
                <span>{metrics.wallet?.topups_completed ?? 0} top-ups OK</span>
              </div>
              <Sparkline data={metrics.trends_last_7_days?.new_unlocks} />
            </article>

            <article className="dash-kpi">
              <span className="dash-kpi-label">Usuarios</span>
              <strong className="dash-kpi-value">{metrics.users?.total ?? 0}</strong>
              <div className="dash-kpi-meta">
                <span className="pill ok">{metrics.users?.active ?? 0} activos</span>
                <span className="pill warn">
                  +{metrics.users?.new_last_7_days ?? 0} / 7d
                </span>
              </div>
            </article>

            <article className="dash-kpi">
              <span className="dash-kpi-label">Matches</span>
              <strong className="dash-kpi-value">{metrics.matches?.total ?? 0}</strong>
              <div className="dash-kpi-meta">
                <span>{metrics.matches?.generated_last_7_days ?? 0} nuevos (7d)</span>
                <span className="pill teal">
                  Conv. {pct(metrics.matches?.unlock_conversion_rate)}
                </span>
              </div>
            </article>

            <article className="dash-kpi">
              <span className="dash-kpi-label">Unlocks</span>
              <strong className="dash-kpi-value">
                {metrics.contacts?.unlocks_total ?? 0}
              </strong>
              <div className="dash-kpi-meta">
                <span>{metrics.contacts?.unlocks_last_7_days ?? 0} esta semana</span>
                <span className="pill navy">{metrics.contacts?.leads_total ?? 0} leads</span>
              </div>
            </article>
          </section>

          {alerts.length > 0 && (
            <section className="dash-alerts">
              {alerts.map(([key, value]) => {
                const meta = ALERT_META[key] || {
                  label: key,
                  to: '/',
                  tone: 'navy',
                }
                return (
                  <Link key={key} to={meta.to} className={`dash-alert tone-${meta.tone}`}>
                    <strong>{value}</strong>
                    <span>{meta.label}</span>
                  </Link>
                )
              })}
            </section>
          )}

          <section className="dash-section card">
            <div className="dash-section-head">
              <h2>Desglose por etapa</h2>
              <span className="muted">Necesidades e inventario</span>
            </div>

            <div className="dash-split">
              <div>
                <div className="dash-stage-title">Necesidades</div>
                <PipelineBar segments={needStages} />
                <div className="dash-stage-grid">
                  {needStages.map((s) => (
                    <div className="dash-stage-card" key={s.key}>
                      <span className="dash-dot" style={{ background: s.color }} />
                      <div>
                        <div className="dash-stage-label">{s.label}</div>
                        <strong>{s.value}</strong>
                      </div>
                    </div>
                  ))}
                </div>
              </div>

              <div>
                <div className="dash-stage-title">Inventario</div>
                <PipelineBar segments={inventoryStages} />
                <div className="dash-stage-grid">
                  {inventoryStages.map((s) => (
                    <div className="dash-stage-card" key={s.key}>
                      <span className="dash-dot" style={{ background: s.color }} />
                      <div>
                        <div className="dash-stage-label">{s.label}</div>
                        <strong>{s.value}</strong>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          </section>

          <section className="dash-two-col">
            <article className="card">
              <div className="dash-section-head">
                <h2>Embudo de conversión</h2>
                <Link to="/reports" className="muted">
                  Ver detalle →
                </Link>
              </div>
              <div className="dash-funnel">
                {[
                  {
                    label: 'Necesidad → Match',
                    value: funnel.need_to_match_rate,
                    count: interactions?.totals?.matches_generated,
                  },
                  {
                    label: 'Match → Unlock',
                    value: funnel.match_to_unlock_rate,
                    count: interactions?.totals?.contacts_unlocked,
                  },
                  {
                    label: 'Unlock → Compra',
                    value: funnel.unlock_to_purchase_rate,
                    count: interactions?.totals?.wantis_spent_on_unlocks,
                  },
                ].map((row) => (
                  <div className="dash-funnel-row" key={row.label}>
                    <div>
                      <div className="dash-stage-label">{row.label}</div>
                      <strong>{pct(row.value)}</strong>
                    </div>
                    <div className="dash-funnel-track">
                      <i style={{ width: pct(row.value) }} />
                    </div>
                    <span className="muted">{row.count ?? 0}</span>
                  </div>
                ))}
              </div>

              <div className="dash-chips" style={{ marginTop: 16 }}>
                <span className="pill teal">
                  Score avg {dist.avg_score ?? '—'}
                </span>
                <span className="pill navy">
                  High match {dist.high_match_count ?? 0}
                </span>
                <span className="pill warn">
                  Mid match {dist.mid_match_count ?? 0}
                </span>
                <span className="pill ok">
                  Rating {metrics.reviews?.avg_rating ?? '—'}
                </span>
              </div>
            </article>

            <article className="card">
              <div className="dash-section-head">
                <h2>Tendencia 7 días</h2>
              </div>
              <div className="dash-trend-grid">
                {(
                  [
                    ['Usuarios', metrics.trends_last_7_days?.new_users],
                    ['Necesidades', metrics.trends_last_7_days?.new_needs],
                    ['Matches', metrics.trends_last_7_days?.new_matches],
                    ['Unlocks', metrics.trends_last_7_days?.new_unlocks],
                  ] as const
                ).map(([label, data]) => {
                  const total = (data || []).reduce((s, d) => s + d.count, 0)
                  return (
                    <div className="dash-trend-card" key={label}>
                      <div className="dash-stage-label">{label}</div>
                      <strong>{total}</strong>
                      <Sparkline data={data} />
                    </div>
                  )
                })}
              </div>
            </article>
          </section>

          <section className="dash-two-col">
            <article className="card">
              <div className="dash-section-head">
                <h2>Distribución operativa</h2>
              </div>
              <div className="dash-dist-list">
                <div className="dash-dist-row">
                  <div className="dash-avatar">U</div>
                  <div className="dash-dist-main">
                    <strong>Usuarios</strong>
                    <div className="dash-chips">
                      <span className="pill ok">Activos {metrics.users?.active ?? 0}</span>
                      <span className="pill warn">
                        Pendientes {metrics.users?.pending_verification ?? 0}
                      </span>
                      <span className="pill danger">
                        Suspendidos {metrics.users?.suspended ?? 0}
                      </span>
                    </div>
                  </div>
                  <span className="dash-count">{metrics.users?.total ?? 0}</span>
                </div>

                <div className="dash-dist-row">
                  <div className="dash-avatar teal">N</div>
                  <div className="dash-dist-main">
                    <strong>Necesidades</strong>
                    <div className="dash-chips">
                      {needStages.map((s) => (
                        <span className="pill navy" key={s.key}>
                          {s.label}: {s.value}
                        </span>
                      ))}
                    </div>
                  </div>
                  <span className="dash-count">{metrics.needs?.total ?? 0}</span>
                </div>

                <div className="dash-dist-row">
                  <div className="dash-avatar navy">I</div>
                  <div className="dash-dist-main">
                    <strong>Inventario</strong>
                    <div className="dash-chips">
                      {inventoryStages.map((s) => (
                        <span className="pill teal" key={s.key}>
                          {s.label}: {s.value}
                        </span>
                      ))}
                    </div>
                  </div>
                  <span className="dash-count">{metrics.inventory?.total_items ?? 0}</span>
                </div>

                <div className="dash-dist-row">
                  <div className="dash-avatar warn">D</div>
                  <div className="dash-dist-main">
                    <strong>Disputas</strong>
                    <div className="dash-chips">
                      <span className="pill danger">Abiertas {metrics.disputes?.open ?? 0}</span>
                      <span className="pill warn">
                        Humanas {metrics.disputes?.in_human_review ?? 0}
                      </span>
                      <span className="pill ok">
                        Resueltas 30d {metrics.disputes?.resolved_last_30_days ?? 0}
                      </span>
                    </div>
                  </div>
                  <span className="dash-count">
                    {pct(metrics.disputes?.approval_rate)} apr.
                  </span>
                </div>
              </div>
            </article>

            <article className="card">
              <div className="dash-section-head">
                <h2>Últimos desbloqueos</h2>
                <Link to="/unlocks" className="muted">
                  Ver todos →
                </Link>
              </div>
              {unlocks.length === 0 ? (
                <p className="muted">Sin desbloqueos recientes</p>
              ) : (
                <div className="dash-dist-list">
                  {unlocks.map((u) => (
                    <div className="dash-dist-row" key={u.id}>
                      <div className="dash-avatar">W</div>
                      <div className="dash-dist-main">
                        <strong>{u.wantis_charged ?? 1} Wanti</strong>
                        <div className="muted" style={{ fontSize: 12 }}>
                          {u.created_at?.slice(0, 19).replace('T', ' ')}
                        </div>
                      </div>
                      <span className="pill navy">{u.outcome || 'UNLOCK'}</span>
                    </div>
                  ))}
                </div>
              )}
            </article>
          </section>

          <section className="card table-wrap">
            <div className="dash-section-head">
              <h2>Actividad reciente</h2>
              <Link to="/audit" className="muted">
                Auditoría →
              </Link>
            </div>
            <table className="data">
              <thead>
                <tr>
                  <th>Acción</th>
                  <th>Entidad</th>
                  <th>Tipo</th>
                  <th>Fecha</th>
                </tr>
              </thead>
              <tbody>
                {activity.length === 0 && (
                  <tr>
                    <td colSpan={4} className="muted">
                      Sin eventos recientes
                    </td>
                  </tr>
                )}
                {activity.map((row) => (
                  <tr key={row.id}>
                    <td>
                      <strong>{row.action}</strong>
                    </td>
                    <td className="mono">{row.entity_id?.slice(0, 8) || '—'}</td>
                    <td>
                      <span className="pill navy">{row.entity}</span>
                    </td>
                    <td className="muted">
                      {row.created_at?.slice(0, 19).replace('T', ' ')}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </section>
        </>
      )}
    </div>
  )
}
