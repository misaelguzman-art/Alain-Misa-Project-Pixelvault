const express = require('express');
const router = express.Router();
const { sql, poolPromise } = require('./database');

// ============================================================
// CLIENTES
// ============================================================

// 1. Registrar nuevo cliente
router.post('/clientes', async (req, res) => {
    const { nombre, medio, apellido, correo, paisid, numero_contacto } = req.body;
    try {
        const pool = await poolPromise;
        await pool.request()
            .input('nombre', sql.VarChar(50), nombre)
            .input('medio', sql.VarChar(50), medio)
            .input('apellido', sql.VarChar(50), apellido)
            .input('correo', sql.VarChar(50), correo)
            .input('paisid', sql.Int, paisid)
            .input('numero_contacto', sql.VarChar(20), numero_contacto)
            .execute('AgregarCliente');
        res.status(201).json({ mensaje: "Cliente registrado con éxito" });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// 2. Desactivar cliente (soft delete)
router.put('/clientes/desactivar/:id', async (req, res) => {
    try {
        const pool = await poolPromise;
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
        const pool = await poolPromise;
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
        const pool = await poolPromise;
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
        const pool = await poolPromise;
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
        const pool = await poolPromise;
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
        const pool = await poolPromise;
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
        const pool = await poolPromise;
        const result = await pool.request().execute('sp_mostrar_juegos_ED_DLC');
        res.json(result.recordset);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// 9. Stock bajo
router.get('/juegos/stock-bajo', async (req, res) => {
    try {
        const pool = await poolPromise;
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
        const pool = await poolPromise;
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
        const pool = await poolPromise;
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
        const pool = await poolPromise;
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
        const pool = await poolPromise;
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
        const pool = await poolPromise;
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
        const pool = await poolPromise;
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
        const pool = await poolPromise;
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
        const pool = await poolPromise;
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
        const pool = await poolPromise;
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
router.post('/login', async (req, res) => {
    const { email } = req.body;
    if (!email) {
        return res.status(400).json({ error: 'Email requerido' });
    }
    try {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('email', sql.VarChar(50), email)
            .execute('LoginCliente');
        if (result.recordset.length === 0) {
            return res.status(404).json({ error: 'Cliente no encontrado o cuenta inactiva' });
        }
        const usuario = result.recordset[0];
        const esAdmin = (email === 'admin@gmail.com');
        usuario.rol = esAdmin ? 'admin' : 'cliente';
        res.json(usuario);
    } catch (err) {
        console.error('Error en /login:', err);
        res.status(500).json({ error: err.message });
    }
});

// 20. Lista de países
router.get('/paises', async (req, res) => {
    try {
        const pool = await poolPromise;
        const result = await pool.request().execute('ObtenerPaises');
        res.json(result.recordset);
    } catch (err) {
        console.error('Error en /paises:', err);
        res.status(500).json({ error: err.message });
    }
});

// ============================================================
// REPORTES ADMIN
// ============================================================

// 21. Directorio de clientes
router.get('/reportes/directorio-clientes', async (req, res) => {
    try {
        const pool = await poolPromise;
        const result = await pool.request().query('SELECT * FROM VW_Directorio_clientes');
        res.json(result.recordset);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// 22. Ingresos por pedido
router.get('/reportes/ingresos-pedidos', async (req, res) => {
    try {
        const pool = await poolPromise;
        const result = await pool.request().query('SELECT * FROM VW_Reporte_ingresos');
        res.json(result.recordset);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// 23. Ingresos por juego/DLC
router.get('/reportes/ventas-por-juego', async (req, res) => {
    try {
        const pool = await poolPromise;
        const result = await pool.request().query('SELECT * FROM VW_Ingresos_Por_Juego');
        res.json(result.recordset);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// 24. Catálogo jerárquico (vista)
router.get('/reportes/catalogo-jerarquia', async (req, res) => {
    try {
        const pool = await poolPromise;
        const result = await pool.request().query('SELECT * FROM VW_TODAS_Juegos_ED_DLC');
        res.json(result.recordset);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// 25. Productos abandonados
router.get('/reportes/productos-abandonados', async (req, res) => {
    try {
        const pool = await poolPromise;
        const result = await pool.request().execute('Venta.ProductosRetiradosCarrito');
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
        const pool = await poolPromise;
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
// EXTRAS (para compatibilidad, ya usan SPs)
// ============================================================

// Asignar método de pago a un pedido (usado internamente)
router.post('/pedidos/asignar-metodo-pago', async (req, res) => {
    const { metododepago, pedidoid } = req.body;
    try {
        const pool = await poolPromise;
        await pool.request()
            .input('metododepago', sql.Int, metododepago)
            .input('pedidoid', sql.Int, pedidoid)
            .execute('SP_TRG_AsignarMetodoPagoAPedido');
        res.json({ message: "Método de pago actualizado correctamente." });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

module.exports = router;