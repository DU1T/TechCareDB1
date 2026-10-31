import { editarSim } from '../../utils/simuladoCatalogos'
// API SIMULADA de PUT /tipos-equipo/{id}
export default defineEventHandler((event) => editarSim(event, 'tipos-equipo'))
