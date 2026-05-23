const express = require('express');
const router = express.Router();
const { sql } = require('./database');


// ============================================================
// CLIENTES
// ============================================================

// 1. Registrar nuevo cliente
router.post('/clientes', async (req, res) => {
    const { nombre, medio, apellido, correo, paisid, numero_contacto, contrasena } = req.body;
    try {
        const pool = req.dbPool;
        await pool.request()
            .input('nombre', sql.VarChar(50), nombre)
            .input('medio', sql.VarChar(50), medio)
            .input('apellido', sql.VarChar(50), apellido)
            .input('correo', sql.VarChar(50), correo)
            .input('paisid', sql.Int, paisid)
            .input('numero_contacto', sql.VarChar(20), numero_contacto)
            .input('contrasena', sql.VarChar(255), contrasena || '12345')
            .execute('AgregarCliente');
        res.status(201).json({ mensaje: "Cliente registrado con éxito" });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// 2. Desactivar cliente (soft delete)
router.put('/clientes/desactivar/:id', async (req, res) => {
    try {
        const pool = req.dbPool;
        await pool.request()
            .input('clienteid', sql.Int, req.params.id)
            .execute('EliminarCliente');
        res.json({ mensaje: "Cliente y sus pedidos relacionados han sido cerrados/inactivados" });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// 3. Obtener métodos de pago de un cliente
router.get('/clientes/:id/pagos', async (req, res) => {
    try {
        const pool = req.dbPool;
        const result = await pool.request()
            .input('Cliente_id', sql.Int, req.params.id)
            .execute('Metodos_pagos_Cliente');
        res.json(result.recordset);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// 4. Historial de pedidos entregados
router.get('/clientes/:id/pedidos-entregados', async (req, res) => {
    try {
        const pool = req.dbPool;
        const result = await pool.request()
            .input('cliente', sql.Int, req.params.id)
            .execute('Historialdepedidosenviados');
        res.json(result.recordset);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// 5. Borrado permanente (peligroso)
router.delete('/clientes/limpieza-total/:id', async (req, res) => {
    try {
        const pool = req.dbPool;
        await pool.request()
            .input('clienteid', sql.Int, req.params.id)
            .execute('NosoftcleanCliente');
        res.json({ mensaje: "Historial completo del cliente eliminado permanentemente." });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// ============================================================
// MÉTODOS DE PAGO
// ============================================================

// 6. Asignar método de pago a un cliente
router.post('/pagos', async (req, res) => {
    const { cliente_id, id_metodo, numero_tarjeta, cvv, fecha_vencimiento } = req.body;
    try {
        const pool = req.dbPool;
        await pool.request()
            .input('cliente_id', sql.Int, cliente_id)
            .input('id_metodo', sql.Int, id_metodo)
            .input('numero_tarjeta', sql.VarChar(50), numero_tarjeta)
            .input('cvv', sql.Char(3), cvv)
            .input('fecha_vencimiento', sql.Date, fecha_vencimiento)
            .execute('AsignarMetodoPago');
        res.json({ mensaje: "Método de pago asignado correctamente" });
    } catch (err) {
        console.error('Error en /pagos:', err);
        res.status(500).json({ error: err.message });
    }
});

// 7. Eliminar método de pago
router.delete('/clientes/pagos', async (req, res) => {
    const { cliente_id, id_metodo, numero_tarjeta } = req.body;
    try {
        const pool = req.dbPool;
        await pool.request()
            .input('cliente_id', sql.Int, cliente_id)
            .input('id_metodo', sql.Int, id_metodo)
            .input('numero_tarjeta', sql.VarChar(50), numero_tarjeta)
            .execute('eliminarmetodoCliente');
        res.json({ mensaje: "Método de pago eliminado con éxito." });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// ============================================================
// CATÁLOGO Y PRODUCTOS
// ============================================================

// 8. Catálogo completo (juegos, ediciones, DLCs)
router.get('/juegos/todo', async (req, res) => {
    try {
        const pool = req.dbPool;
        const result = await pool.request().execute('sp_mostrar_juegos_ED_DLC');
        res.json(result.recordset);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// 9. Stock bajo
router.get('/juegos/stock-bajo', async (req, res) => {
    try {
        const pool = req.dbPool;
        const result = await pool.request().execute('sp_mostrar_juegos_stock_bajo');
        res.json(result.recordset);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// 10. Ediciones de un juego (con stock)
router.get('/productos/:id/ediciones', async (req, res) => {
    const productId = req.params.id;
    console.log('ID recibido:', productId, 'tipo:', typeof productId);
    try {
        const pool = req.dbPool;
        console.log('Pool obtenido');
        const result = await pool.request()
            .input('productid', sql.Int, productId)
            .execute('ObtenerEdicionesProducto');
        console.log('Resultado de SP:', result);
        console.log('Recordset:', result.recordset);
        const data = result.recordset || [];
        console.log('Datos a enviar:', data);
        res.json(data);
    } catch (err) {
        console.error('Error en endpoint /ediciones:', err);
        res.status(500).json({ error: err.message });
    }
});

// 11. Historial de movimientos de un producto
router.get('/productos/historial/:id', async (req, res) => {
    try {
        const pool = req.dbPool;
        const result = await pool.request()
            .input('productid', sql.Int, req.params.id)
            .execute('Product.HistorialMovimientosProducto');
        res.json(result.recordset);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// ============================================================
// CARRITO
// ============================================================

// 12. Obtener carrito activo del cliente
router.get('/clientes/:id/carrito', async (req, res) => {
    try {
        const pool = req.dbPool;
        const result = await pool.request()
            .input('clienteid', sql.Int, req.params.id)
            .execute('ObtenerCarritoActivo');
        
        if (result.recordset.length === 0) {
            return res.json({ carrito: null, items: [] });
        }

        const carro_id = result.recordset[0].carro_id;
        const items = result.recordset
            .filter(r => r.detallesid !== null)
            .map(r => ({
                detallesid: r.detallesid,
                productoid: r.productoid,
                nombre_producto: r.nombre_producto,
                tipo_juego: r.tipo_juego,
                nombre_edicion: r.nombre_edicion,
                cantidad_pedida: r.cantidad_pedida,
                precio_prod: r.precio_prod
            }));

        res.json({
            carrito: { carro_id, estado: result.recordset[0].estado },
            items
        });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// 13. Crear un nuevo carrito
router.post('/clientes/:id/carrito', async (req, res) => {
    try {
        const pool = req.dbPool;
        const result = await pool.request()
            .input('clienteid', sql.Int, req.params.id)
            .output('carro_id', sql.Int)
            .execute('CrearCarrito');
        res.status(201).json({ carro_id: result.output.carro_id });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// 14. Agregar item al carrito
router.post('/carrito/:carro_id/items', async (req, res) => {
    const { productoid, cantidad_pedida, precio_prod } = req.body;
    try {
        const pool = req.dbPool;
        await pool.request()
            .input('carro_id', sql.Int, req.params.carro_id)
            .input('productoid', sql.Int, productoid)
            .input('cantidad_pedida', sql.Int, cantidad_pedida)
            .input('precio_prod', sql.Decimal(10, 2), precio_prod)
            .execute('AgregarItemCarrito');
        res.json({ mensaje: "Producto agregado al carrito." });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// 15. Eliminar item del carrito
router.delete('/carrito/:carro_id/items/:detallesid', async (req, res) => {
    try {
        const pool = req.dbPool;
        await pool.request()
            .input('detallesid', sql.Int, req.params.detallesid)
            .input('carro_id', sql.Int, req.params.carro_id)
            .execute('EliminarItemCarrito');
        res.json({ mensaje: "Item eliminado del carrito." });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// 16. Confirmar compra (transacción completa con códigos de canje)
router.put('/carrito/:carro_id/confirmar', async (req, res) => {
    const { metodo_pago_id } = req.body;
    if (!metodo_pago_id) {
        return res.status(400).json({ error: 'Método de pago requerido' });
    }
    try {
        const pool = req.dbPool;
        const result = await pool.request()
            .input('carro_id', sql.Int, req.params.carro_id)
            .input('metodo_pago_id', sql.Int, metodo_pago_id)
            .output('pedido_id', sql.Int)
            .output('total', sql.Decimal(10, 2))
            .output('codigos_json', sql.NVarChar(sql.MAX))
            .execute('ConfirmarCompra');

        const pedido_id = result.output.pedido_id;
        const total = result.output.total;
        let codigos = [];
        if (result.output.codigos_json) {
            try {
                codigos = JSON.parse(result.output.codigos_json);
            } catch (e) {
                console.error('Error parseando JSON de códigos:', e);
            }
        }
        res.json({
            mensaje: "Pedido creado con éxito.",
            pedido_id,
            total,
            codigos
        });
    } catch (err) {
    console.error('Error en confirmar compra:', err);
    res.status(500).json({ error: err.message });
    }
});

// ============================================================
// PROMOCIONES
// ============================================================

// 17. Promociones vigentes
router.get('/promociones/vigentes', async (req, res) => {
    try {
        const pool = req.dbPool;
        const result = await pool.request().execute('ObtenerPromocionesVigentes');
        res.json(result.recordset);
    } catch (err) {
        console.error('Error en /promociones/vigentes:', err);
        res.json([]);
    }
});

// 18. Aplicar promoción a un pedido
router.post('/pedidos/aplicar-promocion', async (req, res) => {
    const { pedido_id, promocion_id } = req.body;
    try {
        const pool = req.dbPool;
        await pool.request()
            .input('pedido_id', sql.Int, pedido_id)
            .input('promocion_id', sql.Int, promocion_id)
            .execute('SP_TRG_AplicarPromocionPedido');
        res.json({ message: "Proceso ejecutado. Verifique el total del pedido." });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// ============================================================
// LOGIN Y PAÍSES
// ============================================================

// 19. Login por email
// 19. Login por email y contraseña
router.post('/login', async (req, res) => {
    const { email, contrasena } = req.body;
    if (!email) {
        return res.status(400).json({ error: 'Email requerido' });
    }
    try {
        const pool = req.dbPool;
        const result = await pool.request()
            .input('email', sql.VarChar(50), email)
            .input('contrasena', sql.VarChar(255), contrasena || null)
            .execute('LoginCliente');
        if (result.recordset.length === 0) {
            return res.status(404).json({ error: 'Usuario o contraseña incorrectos, o cuenta inactiva' });
        }
        const usuario = result.recordset[0];
        // Mantener compatibilidad pero usar el rol y datos reales del usuario
        res.json(usuario);
    } catch (err) {
        console.error('Error en /login:', err);
        res.status(500).json({ error: err.message });
    }
});

// 20. Lista de países
router.get('/paises', async (req, res) => {
    try {
        const pool = req.dbPool;
        const result = await pool.request().execute('ObtenerPaises');
        res.json(result.recordset);
    } catch (err) {
        console.error('Error en /paises:', err);
        res.status(500).json({ error: err.message });
    }
});

// ============================================================
// REPORTES ADMIN Y AUDITORÍA
// ============================================================

// 21. Directorio de clientes
router.get('/reportes/directorio-clientes', async (req, res) => {
    try {
        const pool = req.dbPool;
        const pais = req.headers['x-pais'] || req.query.pais || 'bolivia';
        
        let list = [];
        
        // 1. Obtener clientes locales
        const resultLocal = await pool.request().query('SELECT * FROM VW_Directorio_clientes');
        list.push(...resultLocal.recordset);
        
        // 2. Si estamos en Bolivia (Central), también intentamos cargar los clientes de Perú (Sucursal)
        if (pais.toLowerCase() === 'bolivia') {
            try {
                const { poolPeru } = require('./database');
                if (!poolPeru.connected) {
                    await poolPeru.connect();
                }
                const resultPeru = await poolPeru.request().query('SELECT * FROM VW_Directorio_clientes');
                list.push(...resultPeru.recordset);
            } catch (peruErr) {
                console.log('⚠️ No se pudo conectar al nodo de Perú para obtener sus clientes (Sucursal offline):', peruErr.message);
                // No arrojamos error para que Bolivia cargue sus clientes locales sin fallar
            }
        }
        
        res.json(list);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// 22. Ingresos por pedido
router.get('/reportes/ingresos-pedidos', async (req, res) => {
    try {
        const pool = req.dbPool;
        const result = await pool.request().query('SELECT * FROM VW_Reporte_ingresos');
        res.json(result.recordset);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// 23. Ingresos por juego/DLC
router.get('/reportes/ventas-por-juego', async (req, res) => {
    try {
        const pool = req.dbPool;
        const result = await pool.request().query('SELECT * FROM VW_Ingresos_Por_Juego');
        res.json(result.recordset);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// 24. Catálogo jerárquico (vista)
router.get('/reportes/catalogo-jerarquia', async (req, res) => {
    try {
        const pool = req.dbPool;
        const result = await pool.request().query('SELECT * FROM VW_TODAS_Juegos_ED_DLC');
        res.json(result.recordset);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// 25. Productos abandonados
router.get('/reportes/productos-abandonados', async (req, res) => {
    try {
        const pool = req.dbPool;
        const result = await pool.request().execute('Venta.ProductosRetiradosCarrito');
        res.json(result.recordset);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// 26. Reporte de Auditoría
router.get('/reportes/auditoria', async (req, res) => {
    try {
        const pool = req.dbPool;
        const result = await pool.request().query('SELECT * FROM dbo.Auditoria ORDER BY fecha DESC');
        res.json(result.recordset);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// ============================================================
// HISTORIAL COMPLETO DE PEDIDOS (todos los estados)
// ============================================================

// Todos los pedidos del cliente sin filtrar por estado
router.get('/clientes/:id/pedidos', async (req, res) => {
    try {
        const pool = req.dbPool;
        const result = await pool.request()
            .input('clienteid', sql.Int, req.params.id)
            .query(`
                SELECT pedido_id, Total_pago, fecha_del_pedido, fecha_de_entrega, estado
                FROM Venta.Pedido
                WHERE Id_cliente = @clienteid
                ORDER BY fecha_del_pedido DESC
            `);
        res.json(result.recordset);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// ============================================================
// ENTREGA DE PEDIDOS Y GESTIÓN DE STOCK
// ============================================================

// Entregar Pedido (pendiente -> entregado)
router.put('/pedidos/:id/entregar', async (req, res) => {
    try {
        const pool = req.dbPool;
        await pool.request()
            .input('pedido_id', sql.Int, req.params.id)
            .execute('dbo.EntregarPedido');
        res.json({ mensaje: "Pedido entregado con éxito." });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// Actualizar Stock de Inventario (Vendedor y Admin)
router.put('/inventario/stock', async (req, res) => {
    const { productid, edicionproductid, cantidad } = req.body;
    try {
        const pool = req.dbPool;
        await pool.request()
            .input('productid', sql.Int, productid || null)
            .input('edicionproductid', sql.Int, edicionproductid || null)
            .input('cantidad', sql.Int, cantidad)
            .execute('dbo.ActualizarInventarioStock');
        res.json({ mensaje: "Stock de inventario actualizado con éxito." });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// Obtener Lista de Inventario para Gestión de Stock
router.get('/inventario/lista', async (req, res) => {
    try {
        const pool = req.dbPool;
        const result = await pool.request().query(`
            SELECT 
                i.inventoryid,
                COALESCE(p_ed.name, p_direct.name) AS nombre_producto,
                COALESCE(p_ed.tipo_juego, p_direct.tipo_juego) AS tipo_juego,
                ed.name AS nombre_edicion,
                i.cantidad,
                i.productid,
                i.edicionproductid
            FROM Product.Inventario i
            LEFT JOIN Product.Product p_direct ON i.productid = p_direct.productid
            LEFT JOIN Product.EdicionProduct ep ON i.edicionproductid = ep.edicionproductid
            LEFT JOIN Product.Product p_ed ON ep.productid = p_ed.productid
            LEFT JOIN Product.Edicion ed ON ep.edicionid = ed.edicionid
            ORDER BY nombre_producto, nombre_edicion
        `);
        res.json(result.recordset);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// ============================================================
// RUTAS CRUD ADMINISTRADOR
// ============================================================

// 1. Crear producto
router.post('/admin/productos', async (req, res) => {
    const { name, developerid, tipo_juego, juego_base, precio_base, fecha_de_lanzamiento, paisid, stock_inicial } = req.body;
    try {
        const pool = req.dbPool;
        await pool.request()
            .input('name', sql.VarChar(50), name)
            .input('developerid', sql.Int, developerid)
            .input('tipo_juego', sql.VarChar(20), tipo_juego || 'juego')
            .input('juego_base', sql.Int, juego_base || null)
            .input('precio_base', sql.Decimal(10, 2), precio_base || null)
            .input('fecha_de_lanzamiento', sql.Date, fecha_de_lanzamiento || null)
            .input('paisid', sql.Int, paisid || null)
            .input('stock_inicial', sql.Int, stock_inicial || 0)
            .execute('dbo.CrearProductoAdmin');
        res.status(201).json({ mensaje: "Producto creado con éxito." });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});


// 2. Activar / Desactivar producto
router.put('/admin/productos/:id/estado', async (req, res) => {
    const { estado } = req.body;
    try {
        const pool = req.dbPool;
        await pool.request()
            .input('productid', sql.Int, req.params.id)
            .input('estado', sql.VarChar(20), estado)
            .execute('dbo.DesactivarProductoAdmin');
        res.json({ mensaje: "Estado del producto actualizado con éxito." });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// 3. Crear método de pago
router.post('/admin/pagos', async (req, res) => {
    const { nombre } = req.body;
    try {
        const pool = req.dbPool;
        await pool.request()
            .input('nombre', sql.VarChar(30), nombre)
            .execute('dbo.CrearMetodoPagoAdmin');
        res.status(201).json({ mensaje: "Método de pago creado con éxito." });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// 4. Activar / Desactivar método de pago
router.put('/admin/pagos/:id/estado', async (req, res) => {
    const { estado } = req.body;
    try {
        const pool = req.dbPool;
        await pool.request()
            .input('id_metodo', sql.Int, req.params.id)
            .input('estado', sql.VarChar(20), estado)
            .execute('dbo.DesactivarMetodoPagoAdmin');
        res.json({ mensaje: "Estado del método de pago actualizado." });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// 5. Crear promoción
router.post('/admin/promociones', async (req, res) => {
    const { nombre, descuento, fecha_inicio, fecha_fin } = req.body;
    try {
        const pool = req.dbPool;
        await pool.request()
            .input('nombre', sql.VarChar(50), nombre)
            .input('descuento', sql.Decimal(5, 2), descuento)
            .input('fecha_inicio', sql.Date, fecha_inicio)
            .input('fecha_fin', sql.Date, fecha_fin)
            .execute('dbo.CrearPromocionAdmin');
        res.status(201).json({ mensaje: "Promoción creada con éxito." });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// 6. Activar / Desactivar promoción
router.put('/admin/promociones/:id/estado', async (req, res) => {
    const { estado } = req.body;
    try {
        const pool = req.dbPool;
        await pool.request()
            .input('promocionid', sql.Int, req.params.id)
            .input('estado', sql.VarChar(20), estado)
            .execute('dbo.DesactivarPromocionAdmin');
        res.json({ mensaje: "Estado de la promoción actualizado." });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// 7. Crear edición
router.post('/admin/ediciones', async (req, res) => {
    const { name } = req.body;
    try {
        const pool = req.dbPool;
        await pool.request()
            .input('name', sql.VarChar(20), name)
            .execute('dbo.CrearEdicionAdmin');
        res.status(201).json({ mensaje: "Edición creada con éxito." });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// 8. Activar / Desactivar edición
router.put('/admin/ediciones/:id/estado', async (req, res) => {
    const { estado } = req.body;
    try {
        const pool = req.dbPool;
        await pool.request()
            .input('edicionid', sql.Int, req.params.id)
            .input('estado', sql.VarChar(20), estado)
            .execute('dbo.DesactivarEdicionAdmin');
        res.json({ mensaje: "Estado de la edición actualizado." });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// 9. Unir producto con edición
router.post('/admin/productos-ediciones', async (req, res) => {
    const { productid, edicionid, precio, fecha_lanzamiento } = req.body;
    try {
        const pool = req.dbPool;
        await pool.request()
            .input('productid', sql.Int, productid)
            .input('edicionid', sql.Int, edicionid)
            .input('precio', sql.Decimal(10, 2), precio)
            .input('fecha_lanzamiento', sql.Date, fecha_lanzamiento)
            .execute('dbo.UnirProductoEdicion');
        res.status(201).json({ mensaje: "Edición vinculada al producto correctamente." });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// ============================================================
// RUTAS AUXILIARES COMBOS ADMIN
// ============================================================

router.get('/developers', async (req, res) => {
    try {
        const pool = req.dbPool;
        const result = await pool.request().query('SELECT developerid, name FROM Product.Developer ORDER BY name');
        res.json(result.recordset);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

router.get('/categorias', async (req, res) => {
    try {
        const pool = req.dbPool;
        const result = await pool.request().query('SELECT id_categoria, nombre FROM Product.Categoria ORDER BY nombre');
        res.json(result.recordset);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

router.get('/plataformas', async (req, res) => {
    try {
        const pool = req.dbPool;
        const result = await pool.request().query('SELECT id_plataforma, nombre FROM Product.Plataforma ORDER BY nombre');
        res.json(result.recordset);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

router.get('/ediciones/lista', async (req, res) => {
    try {
        const pool = req.dbPool;
        const result = await pool.request().query('SELECT edicionid, name, estado FROM Product.Edicion ORDER BY name');
        res.json(result.recordset);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

router.get('/productos/lista', async (req, res) => {
    try {
        const pool = req.dbPool;
        const result = await pool.request().query("SELECT productid, name, estado FROM Product.Product WHERE tipo_juego = 'juego' ORDER BY name");
        res.json(result.recordset);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

router.get('/promociones/lista', async (req, res) => {
    try {
        const pool = req.dbPool;
        const result = await pool.request().query("SELECT promocionid, nombre, descuento, fecha_inicio, fecha_fin, estado FROM Marketing.Promocion ORDER BY nombre");
        res.json(result.recordset);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

router.get('/pagos/lista', async (req, res) => {
    try {
        const pool = req.dbPool;
        const result = await pool.request().query("SELECT id_metodo, nombre, estado FROM Metodo_Pago ORDER BY nombre");
        res.json(result.recordset);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// ============================================================
// EXTRAS (para compatibilidad, ya usan SPs)
// ============================================================

// Asignar método de pago a un pedido (usado internamente)
router.post('/pedidos/asignar-metodo-pago', async (req, res) => {
    const { metododepago, pedidoid } = req.body;
    try {
        const pool = req.dbPool;
        await pool.request()
            .input('metododepago', sql.Int, metododepago)
            .input('pedidoid', sql.Int, pedidoid)
            .execute('SP_TRG_AsignarMetodoPagoAPedido');
        res.json({ message: "Método de pago actualizado correctamente." });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// Crear Desarrollador (Developer) desde el panel de administración
router.post('/admin/developers', async (req, res) => {
    const { name } = req.body;
    if (!name) return res.status(400).json({ error: 'Nombre del desarrollador requerido' });
    try {
        const pool = req.dbPool;
        await pool.request()
            .input('name', sql.VarChar(50), name)
            .query('INSERT INTO Product.Developer (name) VALUES (@name)');
        res.status(201).json({ mensaje: "Desarrollador creado con éxito." });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

module.exports = router;