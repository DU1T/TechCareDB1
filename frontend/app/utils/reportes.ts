/*
  Catálogo de reportes: la pantalla /reportes se arma SOLO con esta lista.
  Para sumar un reporte basta con agregar un objeto a REPORTES:
    - ruta:       endpoint de la API (GET), relativo a /api
    - filtros:    parámetros que se envían como ?nombre=valor (vacío = sin filtro)
    - resultados: una tabla por resultado. Si la API devuelve una lista, se usa el primero.
                  Si devuelve un objeto { facturas: [...], pagos: [...] }, cada resultado
                  declara su clave ('facturas', 'pagos') y se muestra en su propia tabla.
    - validar:    regla entre filtros (p. ej. "indique cliente o NIT"); devuelve el mensaje o ''.
  Las fechas invertidas (fechaInicio > fechaFin) se revisan solas para todos los reportes.
*/

// Listas que la pantalla sabe pedir a la API para llenar un filtro de tipo 'lista'
export const CATALOGOS = {
  bodegas: { ruta: '/bodegas', valor: (f: any) => f.idBodega, etiqueta: (f: any) => f.nombre },
  categorias: { ruta: '/categorias', valor: (f: any) => f.idCategoria, etiqueta: (f: any) => f.nombre },
  proveedores: { ruta: '/proveedores', valor: (f: any) => f.idProveedor, etiqueta: (f: any) => f.nombre },
  repuestos: { ruta: '/repuestos', valor: (f: any) => f.idRepuesto, etiqueta: (f: any) => `${f.codigo} · ${f.nombre}` },
  tecnicos: { ruta: '/tecnicos', valor: (f: any) => f.idUsuario, etiqueta: (f: any) => f.nombreCompleto },
} as const
export type Catalogo = keyof typeof CATALOGOS

export type FiltroReporte = {
  nombre: string // nombre del parámetro en la API
  etiqueta: string
  tipo: 'texto' | 'numero' | 'fecha' | 'lista' | 'casilla'
  opciones?: { label: string; value: string }[] // lista con valores fijos
  catalogo?: Catalogo // lista que se llena desde la API
  obligatorio?: boolean
  ayuda?: string
}

// Cómo se muestra cada celda (ver ReporteTabla.vue)
export type Formato = 'texto' | 'numero' | 'decimal' | 'moneda' | 'fecha' | 'fechaHora' | 'estado'

export type ColumnaReporte = {
  clave: string // campo de la fila que devuelve la API
  etiqueta: string
  formato?: Formato
  valor?: (fila: Record<string, any>) => unknown // para combinar campos (p. ej. marca + modelo)
}

export type ResultadoReporte = {
  clave?: string // solo si la API devuelve varios resultados con nombre
  titulo?: string
  columnas: ColumnaReporte[]
}

export type Reporte = {
  numero: number
  titulo: string
  descripcion: string
  grupo: string
  ruta: string
  filtros: FiltroReporte[]
  resultados: ResultadoReporte[]
  validar?: (valores: Record<string, unknown>) => string
}

// ---- Filtros y columnas que se repiten
const fechas: FiltroReporte[] = [
  { nombre: 'fechaInicio', etiqueta: 'Desde', tipo: 'fecha' },
  { nombre: 'fechaFin', etiqueta: 'Hasta', tipo: 'fecha' },
]
const tecnico: FiltroReporte = { nombre: 'idTecnico', etiqueta: 'Técnico', tipo: 'lista', catalogo: 'tecnicos' }
const bodega: FiltroReporte = { nombre: 'idBodega', etiqueta: 'Bodega', tipo: 'lista', catalogo: 'bodegas' }
const equipo: ColumnaReporte = {
  clave: 'equipo',
  etiqueta: 'Equipo',
  valor: (f) => [f.tipoEquipo, [f.marca, f.modelo].filter(Boolean).join(' ')].filter(Boolean).join(' · '),
}
const factura: ColumnaReporte = {
  clave: 'factura',
  etiqueta: 'Factura',
  valor: (f) => (f.numero == null ? null : `${f.serie}-${f.numero}`),
}

export const ESTADOS_ORDEN_ACTIVOS = [
  { label: 'Recibido', value: 'RECIBIDO' },
  { label: 'En diagnóstico', value: 'DIAGNOSTICO' },
  { label: 'Esperando autorización', value: 'ESPERANDO_AUTORIZACION' },
  { label: 'En reparación', value: 'REPARACION' },
  { label: 'Listo para entregar', value: 'LISTO' },
]

export const REPORTES: Reporte[] = [
  // ---------------- Órdenes (B)
  {
    numero: 1,
    titulo: 'Órdenes activas',
    descripcion: 'Órdenes abiertas con días en el taller, cliente, equipo y técnico.',
    grupo: 'Órdenes',
    ruta: '/reportes/1',
    filtros: [
      { nombre: 'estado', etiqueta: 'Estado', tipo: 'lista', opciones: ESTADOS_ORDEN_ACTIVOS },
      {
        nombre: 'prioridad',
        etiqueta: 'Prioridad',
        tipo: 'lista',
        opciones: ['BAJA', 'MEDIA', 'ALTA', 'URGENTE'].map((p) => ({ label: p[0] + p.slice(1).toLowerCase(), value: p })),
      },
      tecnico,
    ],
    resultados: [{
      columnas: [
        { clave: 'numeroOrden', etiqueta: 'Orden' },
        { clave: 'fechaIngreso', etiqueta: 'Ingreso', formato: 'fecha' },
        { clave: 'diasAbierta', etiqueta: 'Días abierta', formato: 'numero' },
        { clave: 'estadoDescripcion', etiqueta: 'Estado' },
        { clave: 'prioridad', etiqueta: 'Prioridad', formato: 'estado' },
        { clave: 'cliente', etiqueta: 'Cliente' },
        equipo,
        { clave: 'numeroSerie', etiqueta: 'Serie' },
        { clave: 'tecnicoAsignado', etiqueta: 'Técnico' },
        { clave: 'recepcionista', etiqueta: 'Recibió' },
      ],
    }],
  },
  {
    numero: 2,
    titulo: 'Historial de cliente',
    descripcion: 'Todas las órdenes de un cliente con diagnóstico y lo facturado.',
    grupo: 'Órdenes',
    ruta: '/reportes/2',
    filtros: [
      { nombre: 'nit', etiqueta: 'NIT', tipo: 'texto', ayuda: 'O el ID del cliente' },
      { nombre: 'idCliente', etiqueta: 'ID de cliente', tipo: 'numero' },
    ],
    validar: (v) => (v.nit || v.idCliente ? '' : 'Indica el NIT o el ID del cliente.'),
    resultados: [{
      columnas: [
        { clave: 'cliente', etiqueta: 'Cliente' },
        { clave: 'nit', etiqueta: 'NIT' },
        { clave: 'numeroOrden', etiqueta: 'Orden' },
        { clave: 'fechaIngreso', etiqueta: 'Ingreso', formato: 'fecha' },
        { clave: 'estado', etiqueta: 'Estado', formato: 'estado' },
        equipo,
        { clave: 'numeroSerie', etiqueta: 'Serie' },
        { clave: 'diagnostico', etiqueta: 'Diagnóstico' },
        { clave: 'tecnico', etiqueta: 'Técnico' },
        factura,
        { clave: 'totalFacturado', etiqueta: 'Facturado', formato: 'moneda' },
      ],
    }],
  },
  {
    numero: 3,
    titulo: 'Historial de equipo',
    descripcion: 'Todo lo que se le ha hecho a un equipo, por número de serie.',
    grupo: 'Órdenes',
    ruta: '/reportes/3',
    filtros: [{ nombre: 'numeroSerie', etiqueta: 'Número de serie', tipo: 'texto', obligatorio: true }],
    resultados: [{
      columnas: [
        { clave: 'numeroOrden', etiqueta: 'Orden' },
        { clave: 'fechaIngreso', etiqueta: 'Ingreso', formato: 'fecha' },
        { clave: 'estado', etiqueta: 'Estado', formato: 'estado' },
        { clave: 'prioridad', etiqueta: 'Prioridad', formato: 'estado' },
        { clave: 'problemaReportado', etiqueta: 'Problema reportado' },
        { clave: 'diagnostico', etiqueta: 'Diagnóstico' },
        { clave: 'tecnico', etiqueta: 'Técnico' },
        { clave: 'estadoReparacion', etiqueta: 'Reparación', formato: 'estado' },
        { clave: 'costoManoObra', etiqueta: 'Mano de obra', formato: 'moneda' },
        { clave: 'fechaFin', etiqueta: 'Terminada', formato: 'fecha' },
        factura,
        { clave: 'totalFacturado', etiqueta: 'Facturado', formato: 'moneda' },
      ],
    }],
  },
  {
    numero: 4,
    titulo: 'Productividad por técnico',
    descripcion: 'Diagnósticos, reparaciones terminadas, horas y mano de obra en un periodo.',
    grupo: 'Órdenes',
    ruta: '/reportes/4',
    filtros: [tecnico, ...fechas],
    resultados: [{
      columnas: [
        { clave: 'tecnico', etiqueta: 'Técnico' },
        { clave: 'diagnosticos', etiqueta: 'Diagnósticos', formato: 'numero' },
        { clave: 'reparacionesFinalizadas', etiqueta: 'Reparaciones terminadas', formato: 'numero' },
        { clave: 'horasRegistradas', etiqueta: 'Horas', formato: 'decimal' },
        { clave: 'manoObraGenerada', etiqueta: 'Mano de obra', formato: 'moneda' },
      ],
    }],
  },

  // ---------------- Inventario y compras (C)
  {
    numero: 5,
    titulo: 'Repuestos utilizados',
    descripcion: 'Repuestos usados en reparaciones con su costo, venta y margen del momento.',
    grupo: 'Inventario',
    ruta: '/reportes/5',
    filtros: [...fechas, tecnico, bodega],
    resultados: [{
      columnas: [
        { clave: 'fechaRegistro', etiqueta: 'Fecha', formato: 'fechaHora' },
        { clave: 'numeroOrden', etiqueta: 'Orden' },
        { clave: 'tecnico', etiqueta: 'Técnico' },
        { clave: 'bodega', etiqueta: 'Bodega' },
        { clave: 'codigo', etiqueta: 'Código' },
        { clave: 'repuesto', etiqueta: 'Repuesto' },
        { clave: 'cantidad', etiqueta: 'Cantidad', formato: 'numero' },
        { clave: 'costoTotal', etiqueta: 'Costo', formato: 'moneda' },
        { clave: 'ventaTotal', etiqueta: 'Venta', formato: 'moneda' },
        { clave: 'margen', etiqueta: 'Margen', formato: 'moneda' },
      ],
    }],
  },
  {
    numero: 6,
    titulo: 'Inventario actual',
    descripcion: 'Existencia, mínimo y valor a costo por bodega y categoría.',
    grupo: 'Inventario',
    ruta: '/reportes/6',
    filtros: [bodega, { nombre: 'idCategoria', etiqueta: 'Categoría', tipo: 'lista', catalogo: 'categorias' }],
    resultados: [{
      columnas: [
        { clave: 'bodega', etiqueta: 'Bodega' },
        { clave: 'categoria', etiqueta: 'Categoría' },
        { clave: 'codigo', etiqueta: 'Código' },
        { clave: 'repuesto', etiqueta: 'Repuesto' },
        { clave: 'existencia', etiqueta: 'Existencia', formato: 'numero' },
        { clave: 'stockMinimo', etiqueta: 'Mínimo', formato: 'numero' },
        { clave: 'precioCompraRef', etiqueta: 'Costo unitario', formato: 'moneda' },
        { clave: 'valorInventario', etiqueta: 'Valor', formato: 'moneda' },
        { clave: 'estadoStock', etiqueta: 'Estado', formato: 'estado' },
      ],
    }],
  },
  {
    numero: 7,
    titulo: 'Repuestos bajo mínimo',
    descripcion: 'Lo que hay que reponer, empezando por lo que más falta.',
    grupo: 'Inventario',
    ruta: '/reportes/7',
    filtros: [bodega],
    resultados: [{
      columnas: [
        { clave: 'bodega', etiqueta: 'Bodega' },
        { clave: 'codigo', etiqueta: 'Código' },
        { clave: 'repuesto', etiqueta: 'Repuesto' },
        { clave: 'categoria', etiqueta: 'Categoría' },
        { clave: 'existencia', etiqueta: 'Existencia', formato: 'numero' },
        { clave: 'stockMinimo', etiqueta: 'Mínimo', formato: 'numero' },
        { clave: 'faltante', etiqueta: 'Faltante', formato: 'numero' },
        { clave: 'estadoStock', etiqueta: 'Estado', formato: 'estado' },
      ],
    }],
  },
  {
    numero: 8,
    titulo: 'Compras por proveedor',
    descripcion: 'Cada línea comprada con su costo del momento, incluidas las compras pendientes.',
    grupo: 'Inventario',
    ruta: '/reportes/8',
    filtros: [
      { nombre: 'idProveedor', etiqueta: 'Proveedor', tipo: 'lista', catalogo: 'proveedores' },
      {
        nombre: 'estado',
        etiqueta: 'Estado',
        tipo: 'lista',
        opciones: [
          { label: 'Pendiente', value: 'PENDIENTE' },
          { label: 'Recibida', value: 'RECIBIDA' },
          { label: 'Anulada', value: 'ANULADA' },
        ],
      },
      ...fechas,
    ],
    resultados: [{
      columnas: [
        { clave: 'proveedor', etiqueta: 'Proveedor' },
        { clave: 'numeroDocumento', etiqueta: 'Documento' },
        { clave: 'fechaCompra', etiqueta: 'Fecha', formato: 'fecha' },
        { clave: 'estado', etiqueta: 'Estado', formato: 'estado' },
        { clave: 'fechaRecepcion', etiqueta: 'Recibida', formato: 'fecha' },
        { clave: 'bodegaDestino', etiqueta: 'Bodega destino' },
        { clave: 'codigo', etiqueta: 'Código' },
        { clave: 'repuesto', etiqueta: 'Repuesto' },
        { clave: 'cantidad', etiqueta: 'Cantidad', formato: 'numero' },
        { clave: 'costoUnitario', etiqueta: 'Costo unitario', formato: 'moneda' },
        { clave: 'subtotal', etiqueta: 'Subtotal', formato: 'moneda' },
      ],
    }],
  },
  {
    numero: 9,
    titulo: 'Kárdex',
    descripcion: 'Entradas y salidas de cada repuesto con la existencia antes y después.',
    grupo: 'Inventario',
    ruta: '/reportes/9',
    filtros: [bodega, { nombre: 'idRepuesto', etiqueta: 'Repuesto', tipo: 'lista', catalogo: 'repuestos' }, ...fechas],
    resultados: [{
      columnas: [
        { clave: 'fechaMovimiento', etiqueta: 'Fecha', formato: 'fechaHora' },
        { clave: 'bodega', etiqueta: 'Bodega' },
        { clave: 'codigo', etiqueta: 'Código' },
        { clave: 'repuesto', etiqueta: 'Repuesto' },
        { clave: 'tipo', etiqueta: 'Tipo', formato: 'estado' },
        { clave: 'documentoOrigen', etiqueta: 'Origen' },
        { clave: 'cantidad', etiqueta: 'Cantidad', formato: 'numero' },
        { clave: 'existenciaAnterior', etiqueta: 'Antes', formato: 'numero' },
        { clave: 'existenciaResultante', etiqueta: 'Después', formato: 'numero' },
        { clave: 'usuario', etiqueta: 'Usuario' },
      ],
    }],
  },

  // ---------------- Facturación (A)
  {
    numero: 10,
    titulo: 'Facturas con saldo',
    descripcion: 'Cuentas por cobrar: cada factura con lo pagado y lo pendiente, y el detalle de sus pagos.',
    grupo: 'Facturación',
    ruta: '/reportes/10',
    filtros: [
      // La casilla solo se envía si está marcada; sin ella el reporte muestra solo facturas con saldo
      { nombre: 'incluirPagadas', etiqueta: 'Incluir facturas ya pagadas', tipo: 'casilla' },
      { nombre: 'idCliente', etiqueta: 'ID de cliente', tipo: 'numero' },
      ...fechas,
    ],
    resultados: [
      {
        clave: 'facturas',
        titulo: 'Facturas',
        columnas: [
          { clave: 'numeroFactura', etiqueta: 'Factura' },
          { clave: 'fechaEmision', etiqueta: 'Emisión', formato: 'fecha' },
          { clave: 'numeroOrden', etiqueta: 'Orden' },
          { clave: 'cliente', etiqueta: 'Cliente' },
          { clave: 'nitFacturacion', etiqueta: 'NIT' },
          { clave: 'total', etiqueta: 'Total', formato: 'moneda' },
          { clave: 'totalPagado', etiqueta: 'Pagado', formato: 'moneda' },
          { clave: 'saldo', etiqueta: 'Saldo', formato: 'moneda' },
          { clave: 'estadoPago', etiqueta: 'Estado', formato: 'estado' },
        ],
      },
      {
        clave: 'pagos',
        titulo: 'Pagos de esas facturas',
        columnas: [
          { clave: 'numeroFactura', etiqueta: 'Factura' },
          { clave: 'fechaPago', etiqueta: 'Fecha', formato: 'fechaHora' },
          { clave: 'metodoPago', etiqueta: 'Método' },
          { clave: 'monto', etiqueta: 'Monto', formato: 'moneda' },
          { clave: 'referencia', etiqueta: 'Referencia' },
          { clave: 'estadoPago', etiqueta: 'Estado', formato: 'estado' },
          { clave: 'cajero', etiqueta: 'Cajero' },
          { clave: 'motivoAnulacion', etiqueta: 'Motivo de anulación' },
        ],
      },
    ],
  },
  {
    numero: 11,
    titulo: 'Ingresos por periodo',
    descripcion: 'Facturación mes a mes, separando mano de obra y repuestos (solo facturas emitidas).',
    grupo: 'Facturación',
    ruta: '/reportes/11',
    filtros: [...fechas],
    resultados: [{
      columnas: [
        { clave: 'periodo', etiqueta: 'Periodo' },
        { clave: 'facturas', etiqueta: 'Facturas', formato: 'numero' },
        { clave: 'ingresoManoObra', etiqueta: 'Mano de obra', formato: 'moneda' },
        { clave: 'ingresoRepuestos', etiqueta: 'Repuestos', formato: 'moneda' },
        { clave: 'subtotal', etiqueta: 'Subtotal', formato: 'moneda' },
        { clave: 'impuesto', etiqueta: 'Impuesto', formato: 'moneda' },
        { clave: 'total', etiqueta: 'Total', formato: 'moneda' },
      ],
    }],
  },
]
