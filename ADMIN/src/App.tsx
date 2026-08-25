import { Navigate, Route, Routes } from 'react-router-dom'
import { AppLayout } from './components/AppLayout'
import { useAuth } from './lib/auth'
import { AuditLogsPage } from './pages/AuditLogsPage'
import { CatalogPage } from './pages/CatalogPage'
import { DashboardPage } from './pages/DashboardPage'
import { DisputesPage } from './pages/DisputesPage'
import { InventoryPage } from './pages/InventoryPage'
import { LoginPage } from './pages/LoginPage'
import { MatchesPage } from './pages/MatchesPage'
import { NeedsPage } from './pages/NeedsPage'
import { NotificationsPage } from './pages/NotificationsPage'
import { PackagesPage } from './pages/PackagesPage'
import { ReportsPage } from './pages/ReportsPage'
import { ReviewDisputesPage } from './pages/ReviewDisputesPage'
import { ReviewTagsPage } from './pages/ReviewTagsPage'
import { SettingsPage } from './pages/SettingsPage'
import { TopupsPage } from './pages/TopupsPage'
import { UnlocksPage } from './pages/UnlocksPage'
import { UserDetailPage } from './pages/UserDetailPage'
import { UsersPage } from './pages/UsersPage'

function PrivateRoute({ children }: { children: React.ReactNode }) {
  const { user, isStaff } = useAuth()
  if (!user || !isStaff) return <Navigate to="/login" replace />
  return children
}

export default function App() {
  return (
    <Routes>
      <Route path="/login" element={<LoginPage />} />
      <Route
        path="/"
        element={
          <PrivateRoute>
            <AppLayout />
          </PrivateRoute>
        }
      >
        <Route index element={<DashboardPage />} />
        <Route path="users" element={<UsersPage />} />
        <Route path="users/:id" element={<UserDetailPage />} />
        <Route path="packages" element={<PackagesPage />} />
        <Route path="needs" element={<NeedsPage />} />
        <Route path="inventory" element={<InventoryPage />} />
        <Route path="catalog" element={<CatalogPage />} />
        <Route path="matches" element={<MatchesPage />} />
        <Route path="unlocks" element={<UnlocksPage />} />
        <Route path="disputes" element={<DisputesPage />} />
        <Route path="topups" element={<TopupsPage />} />
        <Route path="review-disputes" element={<ReviewDisputesPage />} />
        <Route path="review-tags" element={<ReviewTagsPage />} />
        <Route path="notifications" element={<NotificationsPage />} />
        <Route path="audit" element={<AuditLogsPage />} />
        <Route path="reports" element={<ReportsPage />} />
        <Route path="settings" element={<SettingsPage />} />
      </Route>
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  )
}
