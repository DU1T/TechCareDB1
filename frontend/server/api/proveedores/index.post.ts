import { crearSim } from '../../utils/simuladoCatalogos'
// API SIMULADA de POST /proveedores
export default defineEventHandler((event) => crearSim(event, 'proveedores'))
