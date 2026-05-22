USE [BD2_tienda];
GO

-- ============================================================
-- DROP DE PROCEDIMIENTOS: CLIENTE
-- ============================================================
DROP PROCEDURE IF EXISTS EliminarCliente;
GO
DROP PROCEDURE IF EXISTS NosoftcleanCliente;
GO
DROP PROCEDURE IF EXISTS Metodos_pagos_Cliente;
GO
DROP PROCEDURE IF EXISTS AgregarCliente;
GO
DROP PROCEDURE IF EXISTS Historialdepedidosenviados;
GO

-- ============================================================
-- DROP DE PROCEDIMIENTOS: PRODUCTO E INVENTARIO
-- ============================================================
DROP PROCEDURE IF EXISTS Product.HistorialMovimientosProducto;
GO
DROP PROCEDURE IF EXISTS Product.InventarioDisponibleProducto;
GO
DROP PROCEDURE IF EXISTS ProductEdicPlaCat;
GO
DROP PROCEDURE IF EXISTS AgregProducto;
GO
DROP PROCEDURE IF EXISTS actualizarpreciodeunaedicion;
GO

-- ============================================================
-- DROP DE PROCEDIMIENTOS: MÉTODOS DE PAGO
-- ============================================================
DROP PROCEDURE IF EXISTS AsignarMetodoPago;
GO
DROP PROCEDURE IF EXISTS eliminarmetodoCliente;
GO

-- ============================================================
-- DROP DE PROCEDIMIENTOS: VENTA Y CARRITO
-- ============================================================
DROP PROCEDURE IF EXISTS Venta.ProductosRetiradosCarrito;
GO