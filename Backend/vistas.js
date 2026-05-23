const express = require('express');
const router = express.Router();
const { sql } = require('./database');

/// 12. Directorio completo de clientes (Nombre, País, Estado)
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

// 13. Reporte detallado de ingresos por pedido
router.get('/reportes/ingresos-pedidos', async (req, res) => {
    try {
        const pool = req.dbPool;
        let result = await pool.request()
            .query('SELECT * FROM VW_Reporte_ingresos');
        
        res.json(result.recordset);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// 14. Ingresos totales generados por cada Juego/DLC
router.get('/reportes/ventas-por-juego', async (req, res) => {
    try {
        const pool = req.dbPool;
        let result = await pool.request()
            .query('SELECT * FROM VW_Ingresos_Por_Juego');
        
        res.json(result.recordset);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// 15. Catálogo completo de Juegos y DLCs (Jerarquía)
// Basado en: VW_TODAS_Juegos_ED_DLC
router.get('/reportes/catalogo-jerarquia', async (req, res) => {
    try {
        const pool = req.dbPool;
        const result = await pool.request()
            .query('SELECT * FROM VW_TODAS_Juegos_ED_DLC');
        res.json(result.recordset);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// 16. Alerta de Stock Bajo (Menos de 10 unidades)
// Basado en: sp_mostrar_juegos_stock_bajo (que usa la vista VW_Juegos_Stock_Bajo)
router.get('/reportes/stock-bajo', async (req, res) => {
    try {
        const pool = req.dbPool;
        const result = await pool.request()
            .execute('sp_mostrar_juegos_stock_bajo'); // Nota: Aquí usamos .execute porque es un SP
        res.json(result.recordset);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// 17. Vista directa de Stock Bajo (sin ordenamiento de SP)
// Basado en: VW_Juegos_Stock_Bajo
router.get('/reportes/vista-stock-bajo', async (req, res) => {
    try {
        const pool = req.dbPool;
        const result = await pool.request()
            .query('SELECT * FROM VW_Juegos_Stock_Bajo');
        res.json(result.recordset);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// 18. Alertas de Inventario
// Basado en la lógica inicial del archivo: Product.v.AlertasInventario
// Nota: En tu SQL estaba comentada, pero aquí la habilitamos si la vista existe en DB
router.get('/reportes/alertas-inventario', async (req, res) => {
    try {
        const pool = req.dbPool;
        const result = await pool.request()
            .query('SELECT * FROM Product.v.AlertasInventario');
        res.json(result.recordset);
    } catch (err) {
        res.status(500).json({ error: "La vista AlertasInventario no existe o está incompleta en SQL" });
    }
});

module.exports = router;