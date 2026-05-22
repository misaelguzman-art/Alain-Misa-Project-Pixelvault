USE [BD2_tienda];
GO

-- ===================================================
-- 1. Obtener países
-- ===================================================
DROP PROCEDURE IF EXISTS ObtenerPaises;
GO
CREATE PROCEDURE ObtenerPaises
AS
BEGIN
    SET NOCOUNT ON;
    SELECT paisid, nombre FROM Paises ORDER BY nombre;
END;
GO

-- ===================================================
-- 2. Obtener carrito activo de un cliente
-- ===================================================
DROP PROCEDURE IF EXISTS ObtenerCarritoActivo;
GO
CREATE PROCEDURE ObtenerCarritoActivo
    @clienteid INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP 1 
        c.carro_id, 
        c.estado, 
        c.fecha_creacion,
        cd.detallesid, 
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

-- ===================================================
-- 3. Crear un nuevo carrito para un cliente
-- ===================================================
DROP PROCEDURE IF EXISTS CrearCarrito;
GO
CREATE PROCEDURE CrearCarrito
    @clienteid INT,
    @carro_id INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO Venta.Carrito (Id_cliente, estado, fecha_creacion)
    VALUES (@clienteid, 'activo', CAST(GETDATE() AS DATE));
    SET @carro_id = SCOPE_IDENTITY();
END;
GO

-- ===================================================
-- 4. Agregar o actualizar un item en el carrito
-- ===================================================
DROP PROCEDURE IF EXISTS AgregarItemCarrito;
GO
CREATE PROCEDURE AgregarItemCarrito
    @carro_id INT,
    @productoid INT,
    @cantidad_pedida INT,
    @precio_prod DECIMAL(10,2)
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM Venta.CarroDetalles WHERE carro_id = @carro_id AND productoid = @productoid)
    BEGIN
        UPDATE Venta.CarroDetalles
        SET cantidad_pedida = cantidad_pedida + @cantidad_pedida
        WHERE carro_id = @carro_id AND productoid = @productoid;
    END
    ELSE
    BEGIN
        INSERT INTO Venta.CarroDetalles (carro_id, productoid, cantidad_pedida, precio_prod)
        VALUES (@carro_id, @productoid, @cantidad_pedida, @precio_prod);
    END
END;
GO

-- ===================================================
-- 5. Eliminar un item del carrito
-- ===================================================
DROP PROCEDURE IF EXISTS EliminarItemCarrito;
GO
CREATE PROCEDURE EliminarItemCarrito
    @detallesid INT,
    @carro_id INT
AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM Venta.CarroDetalles WHERE detallesid = @detallesid AND carro_id = @carro_id;
END;
GO

-- ===================================================
-- 6. Obtener ediciones de un producto (juego base)
-- ===================================================
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
GO

-- ===================================================
-- 7. Obtener promociones vigentes (hoy)
-- ===================================================
DROP PROCEDURE IF EXISTS ObtenerPromocionesVigentes;
GO
CREATE PROCEDURE ObtenerPromocionesVigentes
AS
BEGIN
    SET NOCOUNT ON;
    SELECT promocionid, nombre, descuento, fecha_inicio, fecha_fin
    FROM Marketing.Promocion
    WHERE CAST(GETDATE() AS DATE) BETWEEN fecha_inicio AND fecha_fin
    ORDER BY descuento DESC;
END;
GO

-- ===================================================
-- 8. Login de cliente por email
-- ===================================================
DROP PROCEDURE IF EXISTS LoginCliente;
GO
CREATE PROCEDURE LoginCliente
    @email VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT Id_cliente, nombre, apellido, email, estado, paisid, numero_contacto
    FROM Cliente.Cliente
    WHERE email = @email AND estado = 'activo';
END;
GO

-- ===================================================
-- 9. Confirmar compra (SP extenso - lo dejamos como está)
-- Nota: Este no se incluye porque el usuario lo excluyó.
-- Si deseas agregarlo, se puede hacer en otro script.
-- ===================================================
PRINT 'Procedimientos almacenados creados exitosamente.';