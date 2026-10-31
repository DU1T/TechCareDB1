// Datos en memoria para la API SIMULADA de usuarios y roles (se reinician al reiniciar el servidor de desarrollo)
export const ROLES = [
  { idRol: 1, nombre: 'ADMINISTRADOR', descripcion: 'Acceso total' },
  { idRol: 2, nombre: 'RECEPCION', descripcion: 'Clientes, órdenes y entregas' },
  { idRol: 3, nombre: 'TECNICO', descripcion: 'Diagnóstico y reparación' },
  { idRol: 4, nombre: 'BODEGA', descripcion: 'Inventario y compras' },
  { idRol: 5, nombre: 'CAJA', descripcion: 'Facturas, pagos y entregas' },
]
export type UsuarioSim = { idUsuario: number; username: string; nombreCompleto: string; email: string | null; telefono: string | null; estado: string; fechaCreacion: string; roles: { idRol: number; nombre: string }[] }
const rol = (id: number) => ({ idRol: id, nombre: ROLES.find((r) => r.idRol === id)!.nombre })
export const USUARIOS: UsuarioSim[] = [
  { idUsuario: 1, username: 'administrador1', nombreCompleto: 'Usuario de Administrador', email: null, telefono: null, estado: 'ACTIVO', fechaCreacion: '2026-09-01T08:00:00', roles: [rol(1)] },
  { idUsuario: 2, username: 'recepcion1', nombreCompleto: 'Usuario de Recepción', email: 'recepcion@techcare.com', telefono: '5555-0001', estado: 'ACTIVO', fechaCreacion: '2026-09-01T08:05:00', roles: [rol(2)] },
  { idUsuario: 3, username: 'tecnico1', nombreCompleto: 'Técnico Uno', email: null, telefono: null, estado: 'ACTIVO', fechaCreacion: '2026-09-01T08:10:00', roles: [rol(3)] },
  { idUsuario: 4, username: 'bodega1', nombreCompleto: 'Usuario de Bodega', email: null, telefono: null, estado: 'ACTIVO', fechaCreacion: '2026-09-01T08:15:00', roles: [rol(4)] },
  { idUsuario: 5, username: 'caja1', nombreCompleto: 'Usuario de Caja', email: null, telefono: null, estado: 'ACTIVO', fechaCreacion: '2026-09-01T08:20:00', roles: [rol(5)] },
]
export { rol }
