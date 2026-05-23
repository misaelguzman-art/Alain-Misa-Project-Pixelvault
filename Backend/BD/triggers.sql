--triggers
use BD2_tienda
/*
trigger para quitar o agregar al inventario
*/
CREATE TRIGGER Product.trg_MovimientoInventario
ON Product.MovimientoInventario
INSTEAD OF INSERT
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Variables
    DECLARE @id_prod INT, @id_edicion INT, @cant_movimiento INT, @stock_actual INT, @prov INT;

    SELECT 
        @id_prod = productid, 
        @id_edicion = edicionproductid, 
        @cant_movimiento = cantidad,
        @prov = provedorid
    FROM inserted;

    -- NORMALIZACIÓN DE LLAVES SEGÚN DISEÑO:
    -- 1. Si es juego (edicionproductid no es nulo): productid en Inventario debe ser NULL
    -- 2. Si es complemento/DLC (edicionproductid es nulo): productid debe ser no nulo, edicionproductid NULL
    DECLARE @norm_prod_id INT = NULL;
    DECLARE @norm_edicion_id INT = NULL;

    IF @id_edicion IS NOT NULL
    BEGIN
        SET @norm_prod_id = NULL;
        SET @norm_edicion_id = @id_edicion;
    END
    ELSE
    BEGIN
        SET @norm_prod_id = @id_prod;
        SET @norm_edicion_id = NULL;
    END

    -- 1. Obtener el stock actual
    IF @norm_edicion_id IS NOT NULL
    BEGIN
        SET @stock_actual = ISNULL((SELECT cantidad FROM Product.Inventario WITH (UPDLOCK) WHERE productid IS NULL AND edicionproductid = @norm_edicion_id), 0);
    END
    ELSE
    BEGIN
        SET @stock_actual = ISNULL((SELECT cantidad FROM Product.Inventario WITH (UPDLOCK) WHERE productid = @norm_prod_id AND edicionproductid IS NULL), 0);
    END

    BEGIN TRY
        BEGIN TRANSACTION;

        -- SI EL PROVEEDOR ES NULL (SALIDA)
        IF @prov IS NULL
        BEGIN   
            -- ¿Hay suficiente stock?
            IF @stock_actual < @cant_movimiento
            BEGIN
                RAISERROR('Error: No hay suficiente stock en inventario para realizar esta salida.', 16, 1);
            END

            -- Restar del inventario
            IF @norm_edicion_id IS NOT NULL
            BEGIN
                UPDATE Product.Inventario
                SET cantidad = cantidad - @cant_movimiento
                WHERE productid IS NULL AND edicionproductid = @norm_edicion_id;
            END
            ELSE
            BEGIN
                UPDATE Product.Inventario
                SET cantidad = cantidad - @cant_movimiento
                WHERE productid = @norm_prod_id AND edicionproductid IS NULL;
            END
        END
        
        -- SI EL PROVEEDOR NO ES NULL (ENTRADA)
        ELSE 
        BEGIN  
            -- Verificar si el registro existe en inventario
            DECLARE @exists BIT = 0;
            IF @norm_edicion_id IS NOT NULL
            BEGIN
                IF EXISTS (SELECT 1 FROM Product.Inventario WHERE productid IS NULL AND edicionproductid = @norm_edicion_id)
                    SET @exists = 1;
            END
            ELSE
            BEGIN
                IF EXISTS (SELECT 1 FROM Product.Inventario WHERE productid = @norm_prod_id AND edicionproductid IS NULL)
                    SET @exists = 1;
            END

            IF @exists = 1
            BEGIN
                IF @norm_edicion_id IS NOT NULL
                BEGIN
                    UPDATE Product.Inventario
                    SET cantidad = cantidad + @cant_movimiento
                    WHERE productid IS NULL AND edicionproductid = @norm_edicion_id;
                END
                ELSE
                BEGIN
                    UPDATE Product.Inventario
                    SET cantidad = cantidad + @cant_movimiento
                    WHERE productid = @norm_prod_id AND edicionproductid IS NULL;
                END
            END
            ELSE
            BEGIN
                INSERT INTO Product.Inventario (productid, edicionproductid, cantidad)
                VALUES (@norm_prod_id, @norm_edicion_id, @cant_movimiento);
            END
        END

        -- Finalmente, insertar el registro en el historial de movimientos
        INSERT INTO Product.MovimientoInventario (productid, edicionproductid, cantidad, fecha, provedorid)
        SELECT productid, edicionproductid, cantidad, ISNULL(fecha, GETDATE()), provedorid FROM inserted;

        COMMIT TRANSACTION;
    END TRY 
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        DECLARE @err NVARCHAR(MAX) = ERROR_MESSAGE();
        RAISERROR(@err, 16, 1);
    END CATCH
END;
GO

/*

trigger para cuando en [PEDIDO] se confirme que se entrego y inserte en [MOVIMIENTOINVENTARIO]
*/

IF OBJECT_ID('Venta.trg_Pedido_entregado', 'TR') IS NOT NULL
    DROP TRIGGER Venta.trg_Pedido_entregado;
GO

CREATE TRIGGER trg_Pedido_entregado
on Venta.Pedido 
AFTER UPDATE 
as 
begin
    SET NOCOUNT ON;
    IF EXISTS( 
        select 1 from inserted i  
        join deleted d on d.pedido_id = i.pedido_id
        where i.estado = 'entregado' and d.estado <> 'entregado'
    )
    BEGIN
        BEGIN TRY
            BEGIN TRANSACTION;
                -- verificar si tiene promo y si tiene verificar si esta dentro de la fecha de la promo
                IF EXISTS (
                    SELECT 1 
                    FROM inserted i
                    INNER JOIN Marketing.Promocion mp ON i.promocionid = mp.promocionid
                    WHERE i.fecha_de_entrega > mp.fecha_fin
                )
                BEGIN
                    RAISERROR('se intento agregar una promo que ya expiro para la fecha de entrega', 16, 1);
                END

                INSERT INTO Product.MovimientoInventario (productid, edicionproductid, cantidad, fecha, provedorid)
                SELECT 
                    det.productoid,
                    COALESCE(det.edicionproductid, ep.edicionproductid),
                    det.cantidad_pedida,
                    CAST(GETDATE() AS DATE),
                    NULL
                FROM Venta.PedidoDetalles det  
                LEFT JOIN Product.EdicionProduct ep ON ep.productid = det.productoid
                JOIN inserted i ON i.pedido_id = det.pedido_id
                JOIN deleted d ON d.pedido_id = i.pedido_id
                WHERE i.estado = 'entregado' AND d.estado <> 'entregado';

            COMMIT TRANSACTION;
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
            DECLARE @err NVARCHAR(MAX) = ERROR_MESSAGE();
            RAISERROR(@err, 16, 1);
        END CATCH
    END
end;
GO

/*
trigger de carrito a pedido

si el carrito se actualiza y se cierra para ser comprado o pedido inserta un campo en la tabla pedido con fecha de entrega null

*/



CREATE TRIGGER TRG_CARRITOPEDIDO
ON Venta.Carrito
after update 
AS BEGIN

IF EXISTS ( select 1  
from inserted i  
join deleted d  
on d.carro_id = i.carro_id
where i.estado = 'en_proceso' and d.estado = 'activo')
BEGIN

begin try 
BEGIN TRANSACTION


insert into VENTA.PEDIDO (Id_cliente,
 id_metodo,
 carro_id,
  Total_pago,
   fecha_del_pedido,
    fecha_de_entrega,
     estado,
      promocionid)
select 
i.Id_cliente,
NULL , -- no sabemos el metodo de pago por que tiene varios el cliente
i.carro_id,
(SELECT SUM(cantidad_pedida * precio_prod) 
FROM Venta.CarroDetalles 
WHERE carro_id = i.carro_id),
cast((getdate()) as DATE),
null, -- es la fecha de entrega que se actualiza 
'pendiente',
null -- la promocion que no sabemos igual
from inserted i

declare @idpedido INT 
set @idpedido = scope_identity()

insert into Venta.PedidoDetalles (
    pedido_id, productoid,edicionproductid, cantidad_pedida, precio_prod
)
select @idpedido ,
 cd.productoid ,
 cd.edicionproductid,
 cd.cantidad_pedida,
 cd.precio_prod
from Venta.CarroDetalles cd
join inserted i
on cd.carro_id = i.carro_id
where cd.carro_id = i.carro_id

COMMIT TRANSACTION
END TRY
BEGIN CATCH
ROLLBACK COMMIT
END CATCH
END
END;
GO

/*SP para actualizar el total de pedido segun su promocion */
CREATE PROCEDURE SP_TRG_AplicarPromocionPedido
    @pedido_id INT,
    @promocion_id INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @descuento_pct DECIMAL(5,2);
    DECLARE @total_actual DECIMAL(10,2);
    DECLARE @fecha_pedido DATE;

    -- 1. Obtener datos de la promoción y el pedido
    SELECT @descuento_pct = descuento 
    FROM Marketing.Promocion 
    WHERE promocionid = @promocion_id 
      AND CAST(GETDATE() AS DATE) BETWEEN fecha_inicio AND fecha_fin;

    SELECT @total_actual = Total_pago, @fecha_pedido = fecha_del_pedido
    FROM Venta.Pedido 
    WHERE pedido_id = @pedido_id;

    -- 2. Validaciones
    IF @descuento_pct IS NULL
    BEGIN
        print 'La promoción no existe o ha expirado.'
        RETURN;
    END

    IF @total_actual IS NULL
    BEGIN
        print 'El pedido especificado no existe.'
        RETURN;
    END

    -- 3. Calcular nuevo total y actualizar
    -- El total se recalcula sobre la suma de los detalles para evitar errores de doble descuento
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @nuevo_total DECIMAL(10,2);
        
        -- Calculamos el total base desde los detalles
        SELECT @nuevo_total = SUM(cantidad_pedida * precio_prod)
        FROM Venta.PedidoDetalles
        WHERE pedido_id = @pedido_id;

        -- Aplicamos el descuento (ej: si es 10%, multiplicamos por 0.90)
        SET @nuevo_total = @nuevo_total * (1 - (@descuento_pct / 100));

        UPDATE Venta.Pedido
        SET Total_pago = @nuevo_total,
            promocionid = @promocion_id
        WHERE pedido_id = @pedido_id;

        COMMIT TRANSACTION;
        PRINT 'Promoción aplicada con éxito. Nuevo total: ' + CAST(@nuevo_total AS VARCHAR(20));
    END TRY
    BEGIN CATCH
         ROLLBACK TRANSACTION;
        
    END CATCH
END;
GO

-- un SP para poder agregar un metodo de pago al pedido 

CREATE PROCEDURE SP_TRG_AsignarMetodoPagoAPedido
    @metododepago INT,
    @pedidoid INT
AS 
BEGIN
    

    -- 1. Validaciones de Seguridad
    IF NOT EXISTS (SELECT 1 FROM Venta.Pedido WHERE pedido_id = @pedidoid)
    BEGIN
        print 'error el pedido no existe'

        RETURN;
    END

    -- 2. Validar que el pedido no esté ya 'entregado' o 'cancelado'
    -- No queremos cambiar el método de pago de algo que ya se envió
    IF EXISTS (SELECT 1 FROM Venta.Pedido WHERE pedido_id = @pedidoid AND estado IN ('entregado', 'cancelado'))
    BEGIN
        print 'No se puede cambiar el método de pago de un pedido finalizado.'
        RETURN;
    END

    -- 3. Actualización
    BEGIN TRY
        UPDATE Venta.Pedido
        SET id_metodo = @metododepago
        WHERE pedido_id = @pedidoid;
        
        PRINT 'Método de pago actualizado correctamente para el pedido ' + CAST(@pedidoid AS VARCHAR(10));
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO
