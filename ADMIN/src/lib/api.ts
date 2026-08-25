const API_BASE =
  (import.meta.env.VITE_API_BASE_URL as string | undefined)?.replace(/\/$/, '') ||
  ''

export type ApiError = {
  message: string
  code?: string
  status?: number
}

function getTokens() {
  return {
    access: localStorage.getItem('wanti_admin_access') || '',
    refresh: localStorage.getItem('wanti_admin_refresh') || '',
  }
}

export function saveTokens(access: string, refresh: string) {
  localStorage.setItem('wanti_admin_access', access)
  localStorage.setItem('wanti_admin_refresh', refresh)
}

export function clearTokens() {
  localStorage.removeItem('wanti_admin_access')
  localStorage.removeItem('wanti_admin_refresh')
  localStorage.removeItem('wanti_admin_user')
}

async function refreshAccess(): Promise<boolean> {
  const { refresh } = getTokens()
  if (!refresh) return false
  try {
    const res = await fetch(`${API_BASE}/api/v1/auth/token/refresh/`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
      body: JSON.stringify({ refresh }),
    })
    if (!res.ok) return false
    const data = await res.json()
    if (!data.access) return false
    localStorage.setItem('wanti_admin_access', data.access)
    if (data.refresh) localStorage.setItem('wanti_admin_refresh', data.refresh)
    return true
  } catch {
    return false
  }
}

export async function api<T = unknown>(
  path: string,
  options: RequestInit & { auth?: boolean } = {},
): Promise<T> {
  const { auth = true, headers, ...rest } = options
  const h: Record<string, string> = {
    Accept: 'application/json',
    ...(headers as Record<string, string> | undefined),
  }
  const isFormData = typeof FormData !== 'undefined' && rest.body instanceof FormData
  if (rest.body && !h['Content-Type'] && !isFormData) {
    h['Content-Type'] = 'application/json'
  }
  if (isFormData && h['Content-Type']) {
    delete h['Content-Type']
  }
  if (auth) {
    const { access } = getTokens()
    if (access) h.Authorization = `Bearer ${access}`
  }

  let res = await fetch(`${API_BASE}/api/v1${path}`, { ...rest, headers: h })
  if (res.status === 401 && auth) {
    const ok = await refreshAccess()
    if (ok) {
      const { access } = getTokens()
      h.Authorization = `Bearer ${access}`
      res = await fetch(`${API_BASE}/api/v1${path}`, { ...rest, headers: h })
    }
  }

  if (res.status === 204) return {} as T

  const text = await res.text()
  let data: unknown = {}
  if (text) {
    try {
      data = JSON.parse(text)
    } catch {
      data = { detail: text }
    }
  }

  if (!res.ok) {
    const errObj = (data as { error?: { message?: string; code?: string }; detail?: string })
      ?.error
    const err: ApiError = {
      message: errObj?.message || (data as { detail?: string })?.detail || `Error ${res.status}`,
      code: errObj?.code,
      status: res.status,
    }
    throw err
  }

  return data as T
}

export type Paginated<T> = {
  count: number
  next: string | null
  previous: string | null
  results: T[]
}

export function qs(params: Record<string, string | undefined | null>) {
  const sp = new URLSearchParams()
  Object.entries(params).forEach(([k, v]) => {
    if (v != null && v !== '') sp.set(k, v)
  })
  const s = sp.toString()
  return s ? `?${s}` : ''
}
