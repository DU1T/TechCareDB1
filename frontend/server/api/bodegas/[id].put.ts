import { editarSim } from '../../utils/simuladoCatalogos'
// API SIMULADA de PUT /bodegas/{id}
export default defineEventHandler((event) => editarSim(event, 'bodegas'))
