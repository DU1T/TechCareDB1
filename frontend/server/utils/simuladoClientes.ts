// Datos en memoria para la API SIMULADA de clientes, equipos y catálogos (se reinician al reiniciar el servidor de desarrollo)
export type ClienteSim = { idCliente: number; tipoCliente: string; nit: string; nombre: string; telefono: string | null; email: string | null; direccion: string | null; estado: string; fechaRegistro: string }
export type EquipoSim = { idEquipo: number; idCliente: number; cliente: string; idTipoEquipo: number; tipoEquipo: string; idMarca: number; marca: string; modelo: string; numeroSerie: string; descripcion: string | null; estado: string; fechaRegistro: string }

export const TIPOS = [{ idTipoEquipo: 1, nombre: 'Laptop' }, { idTipoEquipo: 2, nombre: 'Celular' }, { idTipoEquipo: 3, nombre: 'Impresora' }, { idTipoEquipo: 4, nombre: 'Computadora de escritorio' }]
export const MARCAS = [{ idMarca: 1, nombre: 'Lenovo' }, { idMarca: 2, nombre: 'Samsung' }, { idMarca: 3, nombre: 'HP' }, { idMarca: 4, nombre: 'Dell' }]

export const CLIENTES: ClienteSim[] = [
  { idCliente: 1, tipoCliente: 'INDIVIDUAL', nit: '1234567-8', nombre: 'María López', telefono: '5555-1234', email: 'maria@correo.com', direccion: 'Zona 1, Guatemala', estado: 'ACTIVO', fechaRegistro: '2026-09-01T10:00:00' },
  { idCliente: 2, tipoCliente: 'INDIVIDUAL', nit: 'CF', nombre: 'Carlos Méndez', telefono: '5555-9876', email: null, direccion: null, estado: 'ACTIVO', fechaRegistro: '2026-09-05T15:30:00' },
  { idCliente: 3, tipoCliente: 'EMPRESA', nit: '9876543-2', nombre: 'Taller Los Pinos, S.A.', telefono: '2222-0000', email: 'compras@lospinos.com', direccion: 'Zona 12, Guatemala', estado: 'ACTIVO', fechaRegistro: '2026-09-10T09:00:00' },
]
export const EQUIPOS: EquipoSim[] = [
  { idEquipo: 1, idCliente: 1, cliente: 'María López', idTipoEquipo: 1, tipoEquipo: 'Laptop', idMarca: 1, marca: 'Lenovo', modelo: 'ThinkPad E14', numeroSerie: 'LNV-0001', descripcion: null, estado: 'ACTIVO', fechaRegistro: '2026-09-01T10:10:00' },
  { idEquipo: 2, idCliente: 2, cliente: 'Carlos Méndez', idTipoEquipo: 2, tipoEquipo: 'Celular', idMarca: 2, marca: 'Samsung', modelo: 'A54', numeroSerie: 'SMG-0002', descripcion: 'Pantalla estrellada', estado: 'ACTIVO', fechaRegistro: '2026-09-05T15:40:00' },
  { idEquipo: 3, idCliente: 3, cliente: 'Taller Los Pinos, S.A.', idTipoEquipo: 3, tipoEquipo: 'Impresora', idMarca: 3, marca: 'HP', modelo: 'LaserJet M404', numeroSerie: 'HP-0003', descripcion: null, estado: 'ACTIVO', fechaRegistro: '2026-09-10T09:10:00' },
]
export const ahora = () => new Date().toISOString().slice(0, 19)
