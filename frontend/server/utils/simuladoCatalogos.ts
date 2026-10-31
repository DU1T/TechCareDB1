import type { H3Event } from 'h3'
import { MARCAS, TIPOS } from './simuladoClientes'

// Datos en memoria para la API SIMULADA de los catálogos (se reinician al reiniciar el servidor de desarrollo)
export const CATEGORIAS = [{ idCategoria: 1, nombre: 'Pantallas' }, { idCategoria: 2, nombre: 'Baterías' }, { idCategoria: 3, nombre: 'Memorias' }]
export const PROVEEDORES: Record<string, any>[] = [
  { idProveedor: 1, nit: '1111111-1', nombre: 'Distribuidora Tecno, S.A.', contacto: 'Ana Ruiz', telefono: '2222-1111', email: 'ventas@tecno.com', direccion: 'Zona 4', estado: 'ACTIVO' },
  { idProveedor: 2, nit: '2222222-2', nombre: 'Repuestos del Norte', contacto: null, telefono: '2222-2222', email: null, direccion: null, estado: 'ACTIVO' },
]
export const BODEGAS: Record<string, any>[] = [
  { idBodega: 1, codigo: 'BOD-01', nombre: 'Bodega Central', ubicacion: 'Zona 1', estado: 'ACTIVA' },
  { idBodega: 2, codigo: 'BOD-02', nombre: 'Bodega Taller', ubicacion: 'Zona 1', estado: 'ACTIVA' },
]
export const REPUESTOS: Record<string, any>[] = [
  { idRepuesto: 1, codigo: 'REP-001', nombre: 'Pantalla 15.6" FHD', descripcion: null, idCategoria: 1, precioCompraRef: 450, precioVenta: 650, estado: 'ACTIVO' },
  { idRepuesto: 2, codigo: 'REP-002', nombre: 'Batería Lenovo E14', descripcion: 'Original', idCategoria: 2, precioCompraRef: 220, precioVenta: 350, estado: 'ACTIVO' },
]

const ALMACENES: Record<string, { datos: Record<string, any>[]; id: string; claveUnica?: string }> = {
  categorias: { datos: CATEGORIAS, id: 'idCategoria' },
  'tipos-equipo': { datos: TIPOS, id: 'idTipoEquipo' },
  marcas: { datos: MARCAS, id: 'idMarca' },
  proveedores: { datos: PROVEEDORES, id: 'idProveedor', claveUnica: 'nit' },
  bodegas: { datos: BODEGAS, id: 'idBodega', claveUnica: 'codigo' },
  repuestos: { datos: REPUESTOS, id: 'idRepuesto', claveUnica: 'codigo' },
}

export async function crearSim(event: H3Event, recurso: string) {
  requerirSimulado(event)
  const a = ALMACENES[recurso]!
  const b = await readBody(event)
  if (a.claveUnica && a.datos.some((x) => String(x[a.claveUnica!]).toLowerCase() === String(b[a.claveUnica!]).toLowerCase()))
    throw createError({ statusCode: 409, data: { error: `Ya existe un registro con ese ${a.claveUnica}.` } })
  const fila = { ...b, [a.id]: Math.max(0, ...a.datos.map((x) => x[a.id])) + 1 }
  a.datos.push(fila)
  return { [a.id]: fila[a.id] }
}

export async function editarSim(event: H3Event, recurso: string) {
  requerirSimulado(event)
  const a = ALMACENES[recurso]!
  const fila = a.datos.find((x) => x[a.id] === Number(getRouterParam(event, 'id')))
  if (!fila) throw createError({ statusCode: 404, data: { error: 'El registro no existe.' } })
  const b = await readBody(event)
  // El PUT reemplaza la fila completa, igual que la API real: lo que no se envía queda vacío
  for (const k of Object.keys(fila)) if (k !== a.id) delete fila[k]
  Object.assign(fila, b)
  return { actualizado: true }
}
