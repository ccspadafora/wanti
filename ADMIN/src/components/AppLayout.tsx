import { NavLink, Outlet } from 'react-router-dom'
import wantiWordmark from '../assets/wanti-logo-wordmark.png'
import { useAuth } from '../lib/auth'

const LINKS = [
  { to: '/', label: 'Dashboard', end: true },
  { to: '/users', label: 'Usuarios' },
  { to: '/packages', label: 'Paquetes Wanti' },
  { to: '/topups', label: 'Órdenes recarga' },
  { to: '/needs', label: 'Necesidades' },
  { to: '/inventory', label: 'Inventario' },
  { to: '/catalog', label: 'Catálogo vehículos' },
  { to: '/matches', label: 'Matches' },
  { to: '/unlocks', label: 'Desbloqueos' },
  { to: '/disputes', label: 'Disputas' },
  { to: '/review-disputes', label: 'Disputas reseñas' },
  { to: '/review-tags', label: 'Tags reseñas' },
  { to: '/notifications', label: 'Notificaciones' },
  { to: '/audit', label: 'Auditoría' },
  { to: '/reports', label: 'Reportes' },
  { to: '/settings', label: 'Settings' },
]

export function AppLayout() {
  const { user, logout } = useAuth()

  return (
    <div className="layout">
      <aside className="sidebar">
        <div className="brand">
          <img className="brand-logo" src={wantiWordmark} alt="Wanti" />
          <span className="brand-tag">Panel de administración</span>
        </div>
        {LINKS.map((l) => (
          <NavLink
            key={l.to}
            to={l.to}
            end={l.end}
            className={({ isActive }) => `nav-link${isActive ? ' active' : ''}`}
          >
            {l.label}
          </NavLink>
        ))}
        <div className="sidebar-footer">
          <div style={{ fontSize: 13, opacity: 0.85, marginBottom: 8 }}>
            {user?.full_name}
            <br />
            <span style={{ opacity: 0.7 }}>{user?.role}</span>
          </div>
          <button className="btn btn-ghost" onClick={logout}>
            Cerrar sesión
          </button>
        </div>
      </aside>
      <main className="main">
        <Outlet />
      </main>
    </div>
  )
}
