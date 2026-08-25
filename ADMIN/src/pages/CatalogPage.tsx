import { useEffect, useState, type FormEvent } from 'react'
import { api, type ApiError } from '../lib/api'

type Brand = {
  id: string
  name: string
  category: string
  is_popular: boolean
  is_active: boolean
}
type Model = { id: string; name: string; is_popular: boolean; brand_id?: string }
type Year = { id: string; year: number; is_popular: boolean; model_id?: string }
type Version = { id: string; name: string; year: number; model_name?: string }

type ImportReport = {
  dry_run: boolean
  total_rows: number
  created_brands: number
  created_models: number
  created_years: number
  created_versions: number
  updated_versions: number
  skipped_duplicates: number
  specs_upserted: number
  error_count: number
  errors: { row: number; field: string; message: string }[]
  errors_truncated: number
}

export function CatalogPage() {
  const [brands, setBrands] = useState<Brand[]>([])
  const [models, setModels] = useState<Model[]>([])
  const [years, setYears] = useState<Year[]>([])
  const [versions, setVersions] = useState<Version[]>([])
  const [brandId, setBrandId] = useState('')
  const [modelId, setModelId] = useState('')
  const [yearId, setYearId] = useState('')
  const [yearNum, setYearNum] = useState<number | ''>('')
  const [category, setCategory] = useState('CAR')
  const [error, setError] = useState('')
  const [msg, setMsg] = useState('')

  const [newBrand, setNewBrand] = useState({ name: '', category: 'CAR' })
  const [newModel, setNewModel] = useState('')
  const [newYear, setNewYear] = useState('')
  const [newVersion, setNewVersion] = useState('')

  const [csvFile, setCsvFile] = useState<File | null>(null)
  const [importing, setImporting] = useState(false)
  const [preview, setPreview] = useState<ImportReport | null>(null)
  const [updateExisting, setUpdateExisting] = useState(true)
  const [defaultCategory, setDefaultCategory] = useState('CAR')

  async function loadBrands() {
    setError('')
    try {
      const data = await api<{ results: Brand[] }>(
        `/catalog/vehicle/brands/?category=${category}`,
      )
      setBrands(data.results || [])
    } catch (e) {
      setError((e as ApiError).message)
    }
  }

  async function loadModels(id: string) {
    if (!id) {
      setModels([])
      return
    }
    const data = await api<{ results: Model[] }>(`/catalog/vehicle/models/?brand_id=${id}`)
    setModels(data.results || [])
  }

  async function loadYears(id: string) {
    if (!id) {
      setYears([])
      return
    }
    const data = await api<{ results: Year[] }>(`/catalog/vehicle/years/?model_id=${id}`)
    setYears(data.results || [])
  }

  async function loadVersions(mId: string, y: number) {
    if (!mId || !y) {
      setVersions([])
      return
    }
    const data = await api<{ results: Version[] }>(
      `/catalog/vehicle/versions/?model_id=${mId}&year=${y}`,
    )
    setVersions(data.results || [])
  }

  useEffect(() => {
    loadBrands()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [category])

  async function runImport(dryRun: boolean) {
    if (!csvFile) {
      setError('Selecciona un archivo CSV')
      return
    }
    setImporting(true)
    setError('')
    setMsg('')
    try {
      const body = new FormData()
      body.append('file', csvFile)
      body.append('dry_run', dryRun ? 'true' : 'false')
      body.append('update_existing', updateExisting ? 'true' : 'false')
      body.append('default_category', defaultCategory)
      const report = await api<ImportReport>('/catalog/vehicle/import/', {
        method: 'POST',
        body,
      })
      setPreview(report)
      if (dryRun) {
        setMsg(
          `Vista previa: ${report.total_rows} filas · ${report.error_count} errores · ` +
            `+${report.created_versions} versiones nuevas · ${report.updated_versions} actualizaciones`,
        )
      } else {
        setMsg(
          `Importación aplicada: +${report.created_versions} versiones, ` +
            `${report.updated_versions} actualizadas, ${report.error_count} errores`,
        )
        await loadBrands()
      }
    } catch (e) {
      setError((e as ApiError).message)
    } finally {
      setImporting(false)
    }
  }

  async function createBrand(e: FormEvent) {
    e.preventDefault()
    setError('')
    setMsg('')
    try {
      await api('/catalog/vehicle/brands/', {
        method: 'POST',
        body: JSON.stringify(newBrand),
      })
      setNewBrand({ name: '', category: newBrand.category })
      setMsg('Marca creada')
      await loadBrands()
    } catch (err) {
      setError((err as ApiError).message)
    }
  }

  async function createModel(e: FormEvent) {
    e.preventDefault()
    if (!brandId) return
    try {
      await api('/catalog/vehicle/models/', {
        method: 'POST',
        body: JSON.stringify({ brand_id: brandId, name: newModel }),
      })
      setNewModel('')
      setMsg('Modelo creado')
      await loadModels(brandId)
    } catch (err) {
      setError((err as ApiError).message)
    }
  }

  async function createYear(e: FormEvent) {
    e.preventDefault()
    if (!modelId) return
    try {
      await api('/catalog/vehicle/years/', {
        method: 'POST',
        body: JSON.stringify({ model_id: modelId, year: Number(newYear) }),
      })
      setNewYear('')
      setMsg('Año creado')
      await loadYears(modelId)
    } catch (err) {
      setError((err as ApiError).message)
    }
  }

  async function createVersion(e: FormEvent) {
    e.preventDefault()
    if (!modelId || !yearNum) return
    try {
      await api('/catalog/vehicle/versions/', {
        method: 'POST',
        body: JSON.stringify({
          model_id: modelId,
          year: yearNum,
          name: newVersion,
        }),
      })
      setNewVersion('')
      setMsg('Versión creada')
      await loadVersions(modelId, Number(yearNum))
    } catch (err) {
      setError((err as ApiError).message)
    }
  }

  async function downloadTemplate() {
    setError('')
    try {
      // api() espera JSON; plantilla es CSV → fetch autenticado aparte
      const access = localStorage.getItem('wanti_admin_access') || ''
      const base =
        (import.meta.env.VITE_API_BASE_URL as string | undefined)?.replace(/\/$/, '') || ''
      const res = await fetch(`${base}/api/v1/catalog/vehicle/import/template/`, {
        headers: { Authorization: `Bearer ${access}` },
      })
      if (!res.ok) throw new Error(`Error ${res.status}`)
      const blob = await res.blob()
      const url = URL.createObjectURL(blob)
      const a = document.createElement('a')
      a.href = url
      a.download = 'wanti_catalog_template.csv'
      a.click()
      URL.revokeObjectURL(url)
    } catch (e) {
      setError((e as Error).message || 'No se pudo descargar la plantilla')
    }
  }

  return (
    <div>
      <h1 className="page-title">Catálogo de vehículos</h1>
      <p className="page-sub">
        Marca → Modelo → Año → Versión. Usa la carga CSV para actualizaciones masivas con categoría y
        características técnicas.
      </p>
      {error && <p className="error">{error}</p>}
      {msg && <p className="muted">{msg}</p>}

      <div className="card" style={{ marginBottom: 16 }}>
        <h3 style={{ marginTop: 0 }}>Carga masiva CSV</h3>
        <p className="muted" style={{ marginTop: 0 }}>
          Columnas: <code>categoria, marca, modelo, anio, version</code> y opcionalmente{' '}
          <code>combustible, transmision, traccion, activo</code>.
        </p>
        <div className="toolbar" style={{ flexWrap: 'wrap', gap: 8 }}>
          <input
            type="file"
            accept=".csv,text/csv"
            onChange={(e) => {
              setCsvFile(e.target.files?.[0] ?? null)
              setPreview(null)
            }}
          />
          <select value={defaultCategory} onChange={(e) => setDefaultCategory(e.target.value)}>
            <option value="CAR">Default: CAR</option>
            <option value="SUV">Default: SUV</option>
            <option value="MOTO">Default: MOTO</option>
            <option value="TRUCK">Default: TRUCK</option>
            <option value="COLLECTION">Default: COLLECTION</option>
            <option value="NAUTICAL">Default: NAUTICAL</option>
            <option value="HEAVY_MACHINERY">Default: HEAVY_MACHINERY</option>
          </select>
          <label style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
            <input
              type="checkbox"
              checked={updateExisting}
              onChange={(e) => setUpdateExisting(e.target.checked)}
            />
            Actualizar existentes
          </label>
          <button
            className="btn btn-navy"
            type="button"
            disabled={!csvFile || importing}
            onClick={() => runImport(true)}
          >
            {importing ? 'Procesando…' : 'Vista previa'}
          </button>
          <button
            className="btn btn-primary"
            type="button"
            disabled={!csvFile || importing || !preview}
            onClick={() => runImport(false)}
          >
            Aplicar importación
          </button>
          <button className="btn btn-navy" type="button" onClick={downloadTemplate}>
            Descargar plantilla
          </button>
        </div>
        {preview && (
          <div style={{ marginTop: 12 }}>
            <p className="muted">
              Filas {preview.total_rows} · marcas +{preview.created_brands} · modelos +
              {preview.created_models} · años +{preview.created_years} · versiones +
              {preview.created_versions} · actualizadas {preview.updated_versions} · duplicados{' '}
              {preview.skipped_duplicates} · specs {preview.specs_upserted} · errores{' '}
              {preview.error_count}
              {preview.dry_run ? ' (preview)' : ''}
            </p>
            {preview.errors.length > 0 && (
              <div
                style={{
                  maxHeight: 220,
                  overflow: 'auto',
                  border: '1px solid #d7e0e8',
                  borderRadius: 8,
                }}
              >
                <table style={{ width: '100%', fontSize: 13, borderCollapse: 'collapse' }}>
                  <thead>
                    <tr>
                      <th style={{ textAlign: 'left', padding: 8 }}>Fila</th>
                      <th style={{ textAlign: 'left', padding: 8 }}>Campo</th>
                      <th style={{ textAlign: 'left', padding: 8 }}>Error</th>
                    </tr>
                  </thead>
                  <tbody>
                    {preview.errors.map((e, idx) => (
                      <tr key={`${e.row}-${e.field}-${idx}`}>
                        <td style={{ padding: 8 }}>{e.row}</td>
                        <td style={{ padding: 8 }}>{e.field}</td>
                        <td style={{ padding: 8 }}>{e.message}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
                {preview.errors_truncated > 0 && (
                  <p className="muted" style={{ padding: 8 }}>
                    … y {preview.errors_truncated} errores más
                  </p>
                )}
              </div>
            )}
          </div>
        )}
      </div>

      <div className="toolbar">
        <select value={category} onChange={(e) => setCategory(e.target.value)}>
          <option value="CAR">Carros</option>
          <option value="SUV">Camionetas</option>
          <option value="MOTO">Motos</option>
          <option value="COLLECTION">Carros de colección</option>
          <option value="TRUCK">Camiones</option>
          <option value="NAUTICAL">Náutica</option>
          <option value="HEAVY_MACHINERY">Maquinaria pesada</option>
          <option value="OTHER">Otros</option>
        </select>
        <button className="btn btn-navy" type="button" onClick={loadBrands}>
          Recargar marcas
        </button>
      </div>

      <div className="card" style={{ marginBottom: 16 }}>
        <h3 style={{ marginTop: 0 }}>1. Marcas</h3>
        <form className="toolbar" onSubmit={createBrand}>
          <input
            placeholder="Nueva marca"
            value={newBrand.name}
            onChange={(e) => setNewBrand({ ...newBrand, name: e.target.value })}
            required
          />
          <select
            value={newBrand.category}
            onChange={(e) => setNewBrand({ ...newBrand, category: e.target.value })}
          >
            <option value="CAR">CAR</option>
            <option value="SUV">SUV</option>
            <option value="MOTO">MOTO</option>
            <option value="COLLECTION">COLLECTION</option>
            <option value="TRUCK">TRUCK</option>
            <option value="NAUTICAL">NAUTICAL</option>
            <option value="HEAVY_MACHINERY">HEAVY_MACHINERY</option>
            <option value="OTHER">OTHER</option>
          </select>
          <button className="btn btn-primary" type="submit">
            Agregar marca
          </button>
        </form>
        <select
          value={brandId}
          onChange={async (e) => {
            const id = e.target.value
            setBrandId(id)
            setModelId('')
            setYearId('')
            setYearNum('')
            setVersions([])
            await loadModels(id)
          }}
          style={{ width: '100%', marginTop: 10 }}
        >
          <option value="">Seleccionar marca…</option>
          {brands.map((b) => (
            <option key={b.id} value={b.id}>
              {b.name}
              {b.is_popular ? ' ★' : ''}
            </option>
          ))}
        </select>
      </div>

      <div className="card" style={{ marginBottom: 16 }}>
        <h3 style={{ marginTop: 0 }}>2. Modelos</h3>
        <form className="toolbar" onSubmit={createModel}>
          <input
            placeholder="Nuevo modelo"
            value={newModel}
            onChange={(e) => setNewModel(e.target.value)}
            required
            disabled={!brandId}
          />
          <button className="btn btn-primary" type="submit" disabled={!brandId}>
            Agregar modelo
          </button>
        </form>
        <select
          value={modelId}
          disabled={!brandId}
          onChange={async (e) => {
            const id = e.target.value
            setModelId(id)
            setYearId('')
            setYearNum('')
            setVersions([])
            await loadYears(id)
          }}
          style={{ width: '100%', marginTop: 10 }}
        >
          <option value="">Seleccionar modelo…</option>
          {models.map((m) => (
            <option key={m.id} value={m.id}>
              {m.name}
              {m.is_popular ? ' ★' : ''}
            </option>
          ))}
        </select>
      </div>

      <div className="card" style={{ marginBottom: 16 }}>
        <h3 style={{ marginTop: 0 }}>3. Años</h3>
        <form className="toolbar" onSubmit={createYear}>
          <input
            placeholder="Año ej. 2018"
            value={newYear}
            onChange={(e) => setNewYear(e.target.value)}
            required
            disabled={!modelId}
          />
          <button className="btn btn-primary" type="submit" disabled={!modelId}>
            Agregar año
          </button>
        </form>
        <select
          value={yearId}
          disabled={!modelId}
          onChange={async (e) => {
            const id = e.target.value
            setYearId(id)
            const y = years.find((x) => x.id === id)
            const num = y?.year ?? ''
            setYearNum(num)
            if (modelId && num) await loadVersions(modelId, Number(num))
          }}
          style={{ width: '100%', marginTop: 10 }}
        >
          <option value="">Seleccionar año…</option>
          {years.map((y) => (
            <option key={y.id} value={y.id}>
              {y.year}
            </option>
          ))}
        </select>
      </div>

      <div className="card">
        <h3 style={{ marginTop: 0 }}>4. Versiones</h3>
        <form className="toolbar" onSubmit={createVersion}>
          <input
            placeholder="Nueva versión ej. 1.8 LT"
            value={newVersion}
            onChange={(e) => setNewVersion(e.target.value)}
            required
            disabled={!yearNum}
          />
          <button className="btn btn-primary" type="submit" disabled={!yearNum}>
            Agregar versión
          </button>
        </form>
        <ul style={{ marginTop: 12, paddingLeft: 18 }}>
          {versions.map((v) => (
            <li key={v.id}>{v.name}</li>
          ))}
          {!versions.length && <li className="muted">Sin versiones para este año</li>}
        </ul>
      </div>
    </div>
  )
}
