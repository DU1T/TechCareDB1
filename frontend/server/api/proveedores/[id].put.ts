import { editarSim } from '../../utils/simuladoCatalogos'
// API SIMULADA de PUT /proveedores/{id}
export default defineEventHandler((event) => editarSim(event, 'proveedores'))
