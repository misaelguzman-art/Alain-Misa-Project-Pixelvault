use [BD2_tienda]

  











 -- PRODUCTOS
   CREATE NONCLUSTERED INDEX IDX_INVENTARIO_CANTIDAD_10
    ON PRODUCT.INVENTARIO (cantidad)
    where cantidad <=10
    

    CREATE UNIQUE CLUSTERED INDEX IDX_V_Ingresos_Totales 
    ON Venta.VW_Ingresos_Totales (nombre_juego);

    CREATE NONCLUSTERED INDEX IDX_EDICIONPRODUCT_ESTADO
    on Product.EdicionProduct (estado)
    include ( productid , edicionid , fecha_de_lanzamiento)

    CREATE NONCLUSTERED INDEX IDX_PRODUCTO_TIPOJUEGO
    on Product.product (tipo_juego)
    include (juego_base)

 -- VENTAS

  CREATE NONCLUSTERED INDEX IDX_PEDIDO_FECHAPEDIDO
   on Venta.Pedido (fecha_del_pedido)
   include (Id_cliente , Total_pago)

  CREATE NONCLUSTERED INDEX IX_Pedido_Estado 
ON Venta.Pedido (estado);


 -- CLIENTES

CREATE NONCLUSTERED INDEX IX_Cliente_Nombre 
ON Cliente.Cliente (nombre) 
INCLUDE (email, numero_contacto);


