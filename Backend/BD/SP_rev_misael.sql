USE [BD2_tienda]
GO

-- ===================================================
-- CLIENTE
-- ===================================================

CREATE PROCEDURE EliminarCliente --soft clean  
@clienteid INT
AS
BEGIN
begin try

begin transaction 

  UPDATE Venta.Carrito
  SET estado = 'inactivo'
  WHERE Id_cliente = @clienteid;

  UPDATE Venta.Pedido
 SET Estado = 'cerrado'
 WHERE Id_cliente = @clienteid;

 UPDATE Cliente.Cliente
  SET estado = 'cerrado'
 WHERE Id_cliente = @clienteid;

commit transaction
end try
begin catch
rollback transaction
end catch

END;
GO

CREATE PROCEDURE NosoftcleanCliente 
    @clienteid INT
AS
BEGIN
    

    BEGIN TRY
        BEGIN TRANSACTION

           -- pedido detalles
            DELETE Venta.PedidoDetalles
            WHERE pedido_id in (
                SELECT pedido_id 
                FROM Venta.Pedido 
                WHERE Id_cliente = @clienteid
            );

            -- pedido
            DELETE Venta.Pedido
            WHERE Id_cliente = @clienteid;

            --  Detalles de carritos del cliente
            DELETE Venta.CarroDetalles
            WHERE carro_id IN (
                SELECT carro_id 
                FROM Venta.Carrito 
                WHERE Id_cliente = @clienteid
            );

            --  Carritos del cliente
            DELETE Venta.Carrito
            WHERE Id_cliente = @clienteid;

            -- metodos de pagod
            DELETE Cliente.Cliente_Metodo_Pago
            WHERE Id_cliente = @clienteid;

            -- cliente
            DELETE Cliente.Cliente
            WHERE Id_cliente = @clienteid;

        COMMIT TRANSACTION
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE Metodos_pagos_Cliente
    @Cliente_id INT
AS
BEGIN
    SELECT 
        CC.Id_cliente,
        CC.nombre,
        CMP.id_metodo,
        MP.nombre AS MetodoPago,
        CMP.numero_de_tarjeta
    FROM Cliente.Cliente AS CC
    INNER JOIN Cliente.Cliente_Metodo_Pago AS CMP ON CMP.Id_cliente = CC.Id_cliente
    INNER JOIN Metodo_Pago AS MP ON CMP.id_metodo = MP.id_metodo
    WHERE CC.Id_cliente = @Cliente_id;
END;
/*
CREATE PROCEDURE Metodos_pagos_Cliente
@Cliente_id INT
AS
BEGIN


    SELECT 
        CC.Id_cliente,
        CC.nombre,
        COALESCE(MP.nombre, 'No tiene metodo de pago') AS MetodoPago
    FROM Cliente.Cliente AS CC
    LEFT JOIN Cliente.Cliente_Metodo_Pago AS CMP
        ON CMP.Id_cliente = CC.Id_cliente
    LEFT JOIN Metodo_Pago AS MP
        ON CMP.id_metodo = MP.id_metodo
    WHERE CC.Id_cliente = @Cliente_id;

END;*/
GO

CREATE OR ALTER PROCEDURE AgregarCliente
    @nombre VARCHAR(50),
    @medio VARCHAR(50) = NULL, -- El valor por defecto se asigna con =
    @apellido VARCHAR(50),
    @correo VARCHAR(50),
    @paisid INT,
    @numero_contacto VARCHAR(20) 
AS
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION
            
            INSERT INTO Cliente.Cliente (nombre, nmedio, apellido, email, estado, paisid, numero_contacto)
            VALUES (@nombre, @medio, @apellido, @correo, 'activo', @paisid, @numero_contacto);

        COMMIT TRANSACTION
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        
        -- Opcional: Lanzar el error para saber qué falló (ej. correo duplicado)
        THROW; 
    END CATCH
END;
GO
-- ===================================================
-- PRODUCTO E INVENTARIO
-- ===================================================

CREATE PROCEDURE Product.HistorialMovimientosProducto
    @productid INT
AS
BEGIN

    SELECT 
        MI.movimientoid,
        P.name                                      AS producto,
        MI.cantidad,
        CASE 
            WHEN MI.edicionproductid IS NULL THEN  P.tipo_juego
            ELSE E.Name
        END                                         AS formato,
        MI.fecha,
        PR.nombre                                   AS proveedor
    FROM Product.MovimientoInventario AS MI
    INNER JOIN Product.Product AS P
        ON MI.productid = P.productid
    LEFT JOIN Product.EdicionProduct AS EP          -- LEFT porque DLCs no tienen edicion
        ON MI.edicionproductid = EP.edicionproductid
    LEFT JOIN Product.Edicion AS E
        ON EP.edicionid = E.edicionid
    LEFT JOIN Provedor.Provedor AS PR
        ON MI.provedorid = PR.provedorid
    WHERE MI.productid = @productid
    ORDER BY MI.fecha DESC;

END;
GO

CREATE PROCEDURE Historialdepedidosenviados
@cliente INT
AS
BEGIN
    SELECT 
        P.pedido_id,
        P.Total_pago,
        P.fecha_del_pedido,
        P.fecha_de_entrega,
        P.estado
    FROM Venta.Pedido AS P
    INNER JOIN Cliente.Cliente AS CC
        ON P.Id_cliente = CC.Id_cliente
    WHERE P.estado = 'entregado'
      AND CC.Id_cliente = @cliente;

 
END;
GO

-- ===================================================
-- METODOS DE PAGO
-- ===================================================

CREATE OR ALTER PROCEDURE AsignarMetodoPago
    @cliente_id INT,
    @id_metodo INT,
    @numero_tarjeta VARCHAR(50),
    @cvv CHAR(3),
    @fecha_vencimiento DATE   -- Ahora es DATE
AS
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION
            INSERT INTO Cliente.Cliente_Metodo_Pago (id_metodo, Id_cliente, numero_de_tarjeta, CVV, fecha_vencimiento)
            VALUES (@id_metodo, @cliente_id, @numero_tarjeta, @cvv, @fecha_vencimiento);
        COMMIT TRANSACTION
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;

/*
CREATE PROCEDURE AsignarMetodoPago
    @cliente_id INT,
    @id_metodo INT,
    @numero_tarjeta VARCHAR(50),
    @cvv CHAR(3),
    @fecha_vencimiento char(5)
AS
BEGIN
begin try
begin transaction
    INSERT INTO Cliente.Cliente_Metodo_Pago (id_metodo, Id_cliente, numero_de_tarjeta, CVV, fecha_vencimiento)
    VALUES (@id_metodo, @cliente_id, @numero_tarjeta, @cvv, @fecha_vencimiento);
commit transaction
end try
begin catch
if @@trancount > 0
rollback transaction
end catch
END;*/
GO

CREATE OR ALTER PROCEDURE eliminarmetodoCliente 
    @cliente_id INT,
    @id_metodo INT,
    @numero_tarjeta VARCHAR(50)
AS
BEGIN
    DELETE FROM Cliente.Cliente_Metodo_Pago
    WHERE Id_cliente = @cliente_id 
      AND id_metodo = @id_metodo 
      AND numero_de_tarjeta = @numero_tarjeta;
END;
GO

-- ===================================================
-- CARRITO Y VENTAS
-- ===================================================
CREATE OR ALTER PROCEDURE Venta.ProductosRetiradosCarrito
AS
BEGIN
    SELECT 
        P.name          AS producto,
        COUNT(*)        AS veces_retirado
    FROM Venta.Carrito AS C
    INNER JOIN Venta.CarroDetalles AS CD ON CD.carro_id = C.carro_id
    INNER JOIN Product.Product AS P ON P.productid = CD.productoid -- Corregido: productoid
    WHERE C.estado = 'abandonado'
    GROUP BY P.name
    ORDER BY veces_retirado DESC;
END;
GO





CREATE Procedure sp_mostrar_juegos_ED_DLC
 as begin   
Select * from VW_TODAS_Juegos_ED_DLC
ORDER BY GrupoOrden, EsDLC, nombre_juego
end;



Create Procedure sp_mostrar_juegos_stock_bajo
 as begin
 select* from VW_Juegos_Stock_Bajo
 order by cantidad_stock asc
 end;

