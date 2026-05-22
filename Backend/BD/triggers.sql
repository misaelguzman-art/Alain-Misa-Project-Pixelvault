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
    
    -- Variables
    DECLARE @id_prod INT, @id_edicion INT, @cant_movimiento INT, @stock_actual INT, @prov INT;

    SELECT 
        @id_prod = productid, 
        @id_edicion = edicionproductid, 
        @cant_movimiento = cantidad,
        @prov = provedorid
    FROM inserted;

    -- 1. Obtener el stock actual (si no existe, lo tratamos como 0)
    SET @stock_actual = ISNULL((SELECT cantidad FROM Product.Inventario with (UPDLOCK) 
                                WHERE (productid = @id_prod OR (@id_prod IS NULL AND productid IS NULL))
                                AND (edicionproductid = @id_edicion OR (@id_edicion IS NULL AND edicionproductid IS NULL))), 0);

    -- : SI EL PROVEEDOR ES NULL (SALIDA)
    begin try
        begin transaction

    IF @prov IS NULL
    BEGIN   
        
        -- hay suficiente stock?
        IF @stock_actual < @cant_movimiento
        BEGIN
            RAISERROR('Error: No hay suficiente stock en inventario para realizar esta salida.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- Restar del inventario
        UPDATE Product.Inventario
        SET cantidad = cantidad - @cant_movimiento
        WHERE (productid = @id_prod OR (@id_prod IS NULL AND productid IS NULL))
          AND (edicionproductid = @id_edicion OR (@id_edicion IS NULL AND edicionproductid IS NULL));
          
    END
    
    --  SI EL PROVEEDOR NO ES NULL (ENTRADA)
    ELSE 
    BEGIN  
        -- Si el registro no existe en inventario, lo creamos; si existe, sumamos
        IF EXISTS (SELECT 1 FROM Product.Inventario WHERE (productid = @id_prod OR (@id_prod IS NULL AND productid IS NULL)) AND (edicionproductid = @id_edicion OR (@id_edicion IS NULL AND edicionproductid IS NULL)))
        BEGIN
            UPDATE Product.Inventario
            SET cantidad = cantidad + @cant_movimiento
            WHERE (productid = @id_prod OR (@id_prod IS NULL AND productid IS NULL))
              AND (edicionproductid = @id_edicion OR (@id_edicion IS NULL AND edicionproductid IS NULL));
        END
        ELSE
        BEGIN
            INSERT INTO Product.Inventario (productid, edicionproductid, cantidad)
            VALUES (@id_prod, @id_edicion, @cant_movimiento);
        END
    END

    -- Finalmente, insertar el registro en el historial de movimientos
    INSERT INTO Product.MovimientoInventario (productid, edicionproductid, cantidad, fecha, provedorid)
    SELECT productid, edicionproductid, cantidad, ISNULL(fecha, GETDATE()), provedorid FROM inserted; -- forma de insertar valores en una tabla sin usar values
    commit transaction
          end try 
          begin catch
           ROLLBACK TRANSACTION;
            print 'Algun error se produjo y no se pudo realizar el cambio'
          end catch
          
END;
GO

/*

trigger para cuando en [PEDIDO] se confirme que se entrego y inserte en [MOVIMIENTOINVENTARIO]
*/

CREATE TRIGGER trg_Pedido_entregado
on Venta.Pedido 
AFTER  UPDATE 
as 
begin
IF EXISTS( 
    select 1 from inserted i  
join deleted d  
on d.pedido_id = i.pedido_id
where i.estado = 'entregado'  and  d.estado <> 'entregado')
BEGIN
BEGIN TRY
BEGIN TRANSACTION
-- verificar si tiene promo y si tiene verificar si esta dentro de la fecha de la promo
 IF EXISTS (
 SELECT 1 
 FROM inserted i
INNER JOIN Marketing.Promocion mp ON i.promocionid = mp.promocionid
WHERE i.fecha_de_entrega > mp.fecha_fin
            )
 BEGIN
 print 'se intento agregar una promo que ya expiro para la fecha de entrega'
  ROLLBACK TRANSACTION;
 END
 




  insert into Product.MovimientoInventario(productid, 
                edicionproductid, 
                cantidad, 
                fecha, 
                provedorid)
    select 
     det.productoid,
     det.edicionproductid,
     det.cantidad_pedida,
     cast((GETDATE()) as DATE) ,
     NULL
    from Venta.PedidoDetalles det  
    join inserted i  
    on i.pedido_id = det.pedido_id
    join deleted d  
    on d.pedido_id = i.pedido_id
    where i.estado = 'entregado' AND d.estado <> 'entregado';
 COMMIT TRANSACTION
    END TRY
    BEGIN CATCH
    ROLLBACK TRANSACTION
    END CATCH
END
end;
go

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
