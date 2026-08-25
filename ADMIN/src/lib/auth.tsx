import {
  createContext,
  useCallback,
  useContext,
  useMemo,
  useState,
  type ReactNode,
} from 'react'
import { api, clearTokens, saveTokens } from './api'

export type AdminUser = {
  id: string
  email: string
  full_name: string
  role: string
  status: string
}

type AuthState = {
  user: AdminUser | null
  loading: boolean
  login: (email: string, password: string) => Promise<void>
  logout: () => void
  isStaff: boolean
}

const AuthContext = createContext<AuthState | null>(null)

function loadStoredUser(): AdminUser | null {
  try {
    const raw = localStorage.getItem('wanti_admin_user')
    return raw ? (JSON.parse(raw) as AdminUser) : null
  } catch {
    return null
  }
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<AdminUser | null>(() => loadStoredUser())
  const [loading] = useState(false)

  const login = useCallback(async (email: string, password: string) => {
    const tokens = await api<{ access: string; refresh: string }>('/auth/login/', {
      method: 'POST',
      auth: false,
      body: JSON.stringify({ email, password }),
    })
    saveTokens(tokens.access, tokens.refresh)
    const me = await api<AdminUser>('/users/me/')
    if (!['ADMIN', 'MODERATOR'].includes(me.role)) {
      clearTokens()
      throw { message: 'Esta cuenta no tiene acceso al panel admin' }
    }
    localStorage.setItem('wanti_admin_user', JSON.stringify(me))
    setUser(me)
  }, [])

  const logout = useCallback(() => {
    clearTokens()
    setUser(null)
  }, [])

  const value = useMemo(
    () => ({
      user,
      loading,
      login,
      logout,
      isStaff: !!user && ['ADMIN', 'MODERATOR'].includes(user.role),
    }),
    [user, loading, login, logout],
  )

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}

export function useAuth() {
  const ctx = useContext(AuthContext)
  if (!ctx) throw new Error('useAuth fuera de AuthProvider')
  return ctx
}
