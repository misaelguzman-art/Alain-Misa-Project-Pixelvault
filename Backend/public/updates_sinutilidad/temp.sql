/*USE [BD2_tienda];
GO

DROP PROCEDURE IF EXISTS ObtenerEdicionesProducto;
GO

CREATE PROCEDURE ObtenerEdicionesProducto
    @productid INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT 
        ep.edicionproductid,
        e.name AS nombre_edicion,
        ep.precio,
        ep.fecha_lanzamiento,
        ISNULL(inv.cantidad, 0) AS stock
    FROM Product.EdicionProduct ep
    INNER JOIN Product.Edicion e ON e.edicionid = ep.edicionid
    LEFT JOIN Product.Inventario inv ON inv.edicionproductid = ep.edicionproductid
    WHERE ep.productid = @productid
    ORDER BY ep.precio ASC;
END;
GO*/


USE [BD2_tienda];
GO

ALTER PROCEDURE ObtenerCarritoActivo @clienteid INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP 1 
        c.carro_id, 
        c.estado, 
        c.fecha_creacion,
        cd.detallesid,  -- ← esta columna es obligatoria
        cd.productoid, 
        cd.cantidad_pedida, 
        cd.precio_prod,
        p.name AS nombre_producto, 
        p.tipo_juego,
        e.name AS nombre_edicion
    FROM Venta.Carrito c
    LEFT JOIN Venta.CarroDetalles cd ON cd.carro_id = c.carro_id
    LEFT JOIN Product.Product p ON p.productid = cd.productoid
    LEFT JOIN Product.EdicionProduct ep ON ep.edicionproductid = cd.productoid
    LEFT JOIN Product.Edicion e ON e.edicionid = ep.edicionid
    WHERE c.Id_cliente = @clienteid AND c.estado = 'activo'
    ORDER BY c.fecha_creacion DESC;
END;
GO


CREATE OR ALTER PROCEDURE AgregarItemCarrito
    @carro_id INT,
    @productoid INT,
    @cantidad_pedida INT,
    @precio_prod DECIMAL(10,2)
AS
BEGIN
    IF EXISTS (SELECT 1 FROM Venta.CarroDetalles WHERE carro_id = @carro_id AND productoid = @productoid)
        UPDATE Venta.CarroDetalles SET cantidad_pedida = cantidad_pedida + @cantidad_pedida
        WHERE carro_id = @carro_id AND productoid = @productoid;
    ELSE
        INSERT INTO Venta.CarroDetalles (carro_id, productoid, cantidad_pedida, precio_prod)
        VALUES (@carro_id, @productoid, @cantidad_pedida, @precio_prod);
END;
GO

CREATE OR ALTER PROCEDURE EliminarItemCarrito
    @detallesid INT,
    @carro_id INT
AS
BEGIN
    DELETE FROM Venta.CarroDetalles WHERE detallesid = @detallesid AND carro_id = @carro_id;
END;
GO


CREATE OR ALTER PROCEDURE ObtenerEdicionesProducto
    @productid INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT 
        ep.edicionproductid,
        e.name AS nombre_edicion,
        ep.precio,
        ep.fecha_lanzamiento,
        ISNULL(inv.cantidad, 0) AS stock
    FROM Product.EdicionProduct ep
    INNER JOIN Product.Edicion e ON e.edicionid = ep.edicionid
    LEFT JOIN Product.Inventario inv ON inv.edicionproductid = ep.edicionproductid
    WHERE ep.productid = @productid
    ORDER BY ep.precio ASC;
END;
GO

SELECT name FROM sys.procedures 
WHERE name IN ('AgregarCliente', 'EliminarCliente', 'Metodos_pagos_Cliente', 'Historialdepedidosenviados',
               'NosoftcleanCliente', 'AsignarMetodoPago', 'eliminarmetodoCliente', 'sp_mostrar_juegos_ED_DLC',
               'sp_mostrar_juegos_stock_bajo', 'ObtenerEdicionesProducto', 'Product.HistorialMovimientosProducto',
               'ObtenerCarritoActivo', 'CrearCarrito', 'AgregarItemCarrito', 'EliminarItemCarrito', 'ConfirmarCompra',
               'ObtenerPromocionesVigentes', 'SP_TRG_AplicarPromocionPedido', 'LoginCliente', 'ObtenerPaises',
               'SP_TRG_AsignarMetodoPagoAPedido');



EXEC ObtenerEdicionesProducto @productid = 0;


SELECT SPECIFIC_SCHEMA, SPECIFIC_NAME 
FROM INFORMATION_SCHEMA.ROUTINES 
WHERE SPECIFIC_NAME = 'ObtenerEdicionesProducto';


USE [BD2_tienda];
GO

ALTER PROCEDURE sp_mostrar_juegos_ED_DLC
AS
BEGIN
    SELECT 
        pp.productid,   -- ← Agregamos esta línea
        pp.name AS nombre_juego,
        CASE 
            WHEN ep.edicionproductid IS NULL THEN ed.name
            ELSE pp.tipo_juego
        END AS tipo_dejuego,
        padre.name AS Cabeza,
        COALESCE(padre.name, pp.name) AS GrupoOrden,
        CASE WHEN padre.name IS NULL THEN 0 ELSE 1 END AS EsDLC
    FROM Product.Product pp
    LEFT JOIN Product.Product padre ON padre.productid = pp.juego_base
    LEFT JOIN Product.EdicionProduct ep ON ep.edicionproductid = pp.productid
    LEFT JOIN Product.Edicion ed ON ep.edicionid = ed.edicionid
    WHERE pp.estado = 'activo'
    ORDER BY GrupoOrden, EsDLC, nombre_juego;
END;
GO




USE [BD2_tienda];
GO

CREATE OR ALTER PROCEDURE Historialdepedidosenviados
    @cliente INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT 
        p.pedido_id,
        p.Total_pago,
        p.fecha_del_pedido,
        p.fecha_de_entrega,
        p.estado
    FROM Venta.Pedido p
    WHERE p.Id_cliente = @cliente AND p.estado = 'entregado'
    ORDER BY p.fecha_del_pedido DESC;
END;
GO

CREATE OR ALTER PROCEDURE ObtenerCarritoActivo @clienteid INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP 1 
        c.carro_id, 
        c.estado, 
        c.fecha_creacion,
        cd.detallesid,   -- ✅ esta columna es clave
        cd.productoid, 
        cd.cantidad_pedida, 
        cd.precio_prod,
        p.name AS nombre_producto, 
        p.tipo_juego,
        e.name AS nombre_edicion
    FROM Venta.Carrito c
    LEFT JOIN Venta.CarroDetalles cd ON cd.carro_id = c.carro_id
    LEFT JOIN Product.Product p ON p.productid = cd.productoid
    LEFT JOIN Product.EdicionProduct ep ON ep.edicionproductid = cd.productoid
    LEFT JOIN Product.Edicion e ON e.edicionid = ep.edicionid
    WHERE c.Id_cliente = @clienteid AND c.estado = 'activo'
    ORDER BY c.fecha_creacion DESC;
END;
GO


USE [BD2_tienda];
GO

CREATE OR ALTER PROCEDURE ConfirmarCompra
    @carro_id INT,
    @metodo_pago_id INT,
    @pedido_id INT OUTPUT,
    @total DECIMAL(10,2) OUTPUT,
    @codigos_json NVARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1. Cambiar estado del carrito a 'en_proceso' (dispara trigger que crea pedido)
        UPDATE Venta.Carrito SET estado = 'en_proceso' WHERE carro_id = @carro_id;

        -- 2. Obtener el pedido recién creado por el trigger
        SELECT TOP 1 @pedido_id = pedido_id, @total = Total_pago
        FROM Venta.Pedido
        WHERE carro_id = @carro_id
        ORDER BY pedido_id DESC;

        IF @pedido_id IS NULL
            THROW 50000, 'El trigger no pudo crear el pedido.', 1;

        -- 3. Asignar método de pago al pedido
        EXEC SP_TRG_AsignarMetodoPagoAPedido @metodo_pago_id, @pedido_id;

        -- 4. Obtener los items del pedido (productoid, edicionproductid, cantidad_pedida)
        DECLARE @items TABLE (
            idx INT IDENTITY(1,1),
            productoid INT,
            cantidad_pedida INT,
            edicionproductid INT,
            nombre_producto VARCHAR(100),
            nombre_edicion VARCHAR(50)
        );

        INSERT INTO @items (productoid, cantidad_pedida, edicionproductid, nombre_producto, nombre_edicion)
        SELECT 
            pd.productoid,
            pd.cantidad_pedida,
            ep.edicionproductid,
            p.name,
            e.name
        FROM Venta.PedidoDetalles pd
        LEFT JOIN Product.EdicionProduct ep ON ep.edicionproductid = pd.productoid
        LEFT JOIN Product.Product p ON p.productid = pd.productoid
        LEFT JOIN Product.Edicion e ON e.edicionid = ep.edicionid
        WHERE pd.pedido_id = @pedido_id;

        -- 5. Tabla temporal para códigos asignados
        DECLARE @codigos TABLE (producto NVARCHAR(200), codigo VARCHAR(50));

        DECLARE @i INT = 1, @max INT;
        DECLARE @producto_actual NVARCHAR(200);
        DECLARE @cantidad_actual INT;
        DECLARE @edicion_actual INT;
        DECLARE @productoid_actual INT;
        DECLARE @ejemplares TABLE (id INT, codigo VARCHAR(50));

        SELECT @max = COUNT(*) FROM @items;

        WHILE @i <= @max
        BEGIN
            SELECT 
                @producto_actual = ISNULL(nombre_producto, '') + ISNULL(' (' + nombre_edicion + ')', ''),
                @cantidad_actual = cantidad_pedida,
                @edicion_actual = edicionproductid,
                @productoid_actual = productoid
            FROM @items WHERE idx = @i;

            IF @producto_actual IS NULL OR @producto_actual = '' 
                SET @producto_actual = 'Producto #' + CAST(@productoid_actual AS VARCHAR);

            DELETE FROM @ejemplares;

            IF @edicion_actual IS NOT NULL
            BEGIN
                INSERT INTO @ejemplares
                SELECT TOP (@cantidad_actual) id_ejemplar, canjear_codigo
                FROM Product.Ejemplar
                WHERE edicionproductid = @edicion_actual
                  AND estado = 'activo'
                  AND productid IS NULL
                ORDER BY id_ejemplar;
            END
            ELSE
            BEGIN
                INSERT INTO @ejemplares
                SELECT TOP (@cantidad_actual) id_ejemplar, canjear_codigo
                FROM Product.Ejemplar
                WHERE productid = @productoid_actual
                  AND estado = 'activo'
                  AND edicionproductid IS NULL
                ORDER BY id_ejemplar;
            END

            IF (SELECT COUNT(*) FROM @ejemplares) < @cantidad_actual
            BEGIN
                DECLARE @faltantes INT = @cantidad_actual - (SELECT COUNT(*) FROM @ejemplares);
                DECLARE @msg NVARCHAR(200) = 'No hay suficientes códigos disponibles para "' + @producto_actual + '". Faltan ' + CAST(@faltantes AS VARCHAR(10)) + ' unidades.';
                THROW 50000, @msg, 1;
            END

            -- Marcar ejemplares como 'comprado'
            UPDATE Product.Ejemplar
            SET estado = 'comprado'
            WHERE id_ejemplar IN (SELECT id FROM @ejemplares);

            -- Guardar códigos
            INSERT INTO @codigos (producto, codigo)
            SELECT @producto_actual, codigo FROM @ejemplares;

            SET @i = @i + 1;
        END

        -- 6. Marcar carrito como completado
        UPDATE Venta.Carrito
        SET estado = 'completado', fecha_cierre = CAST(GETDATE() AS DATE)
        WHERE carro_id = @carro_id;

        -- 7. Generar JSON manualmente (compatible con versiones antiguas)
        SET @codigos_json = '[' +
            STUFF((SELECT ',' + '{"producto":"' + REPLACE(producto, '"', '\"') + '","codigo":"' + codigo + '"}'
                   FROM @codigos
                   FOR XML PATH('')), 1, 1, '') + ']';

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        DECLARE @err_msg NVARCHAR(MAX) = ERROR_MESSAGE();
        THROW 50000, @err_msg, 1;
    END CATCH
END;
GO


EXEC sp_helptext 'ObtenerCarritoActivo';


EXEC ObtenerCarritoActivo @clienteid = 1;

UPDATE Venta.Pedido SET estado = 'entregado', fecha_de_entrega = GETDATE() WHERE pedido_id = [733];


SELECT carro_id FROM Venta.Carrito WHERE estado = 'completado' AND Id_cliente = [16];




USE BD2_tienda;
GO

SELECT 
    s.name AS esquema,
    t.name AS tabla,
    i.name AS nombre_indice,
    i.type_desc AS tipo_indice,
    i.is_unique AS es_unico,
    i.is_primary_key AS es_primaria,
    STUFF((
        SELECT ', ' + c.name
        FROM sys.index_columns ic
        JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
        WHERE ic.object_id = i.object_id AND ic.index_id = i.index_id
        ORDER BY ic.key_ordinal
        FOR XML PATH('')
    ), 1, 2, '') AS columnas_clave
FROM sys.indexes i
JOIN sys.tables t ON i.object_id = t.object_id
JOIN sys.schemas s ON t.schema_id = s.schema_id
WHERE i.name IS NOT NULL   -- omitir índices heap (sin nombre)
ORDER BY esquema, tabla, nombre_indice;





USE BD2_tienda;
GO

SELECT 
    s.name AS esquema,
    v.name AS nombre_vista,
    v.type_desc AS tipo
FROM sys.views v
JOIN sys.schemas s ON v.schema_id = s.schema_id
ORDER BY esquema, nombre_vista;