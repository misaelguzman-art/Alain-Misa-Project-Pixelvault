use [BD2_tienda]

/*
Misael Alvaro Guzman Villarroel
Inventario


*/
/*
CREATE VIEW Product.v.AlertasInventario AS

select 
from Product.Inventario I
left join Product.Product p on i.productid = p.productid or
*/

alter or create VIEW VW_Reporte_ingresos AS
SELECT 
pe.pedido_id,
pe.fecha_del_pedido,
c.nombre + ' ' + c.apellido as cliente,
Mp.nombre as Metodo_Pago,
pe.Total_pago,
ISNULL(pr.nombre, 'Sin promo') as promocion_aplicada,
pe.estado as Estado_Pedido
From Venta.Pedido Pe  
INNER JOIN Cliente.Cliente c on pe.Id_cliente = c.Id_cliente
INNER JOIN Metodo_Pago MP on pe.id_metodo = mp.id_metodo
LEFT JOIN venta.Promocion Pr on pe.promocionid = pr.promocionid
 
SELECT *FROM VW_Reporte_ingresos

/*
Directorio de clientes
*/

CREATE VIEW VW_Directorio_clientes AS
SELECT 
C.Id_cliente,
c.nombre primer_nombre,
c.apellido apellido,
c.email as correo,
c.numero_contacto as telefono,
p.nombre as pais,
c.estado as estado_usuario
from Cliente.Cliente C  
LEFT JOIN Paises P ON  C.paisid = p.paisid 


select *from VW_Reporte_ingresos

/*
vistas para mostrar los juegos, su tipo y su juego base (si es que tiene)

VISTA
QUE hace: Muestra el nombre del juego, su tipo (si es juego base o DLC) y el nombre del juego base (si es que tiene)
NOMBRE: VW_TODAS_Juegos_ED_DLC
HECHO POR : Alain Flores
FECHA: 12/06/2024
*/


Create or alter View VW_TODAS_Juegos_ED_DLC as
with catalago_juegos as (
select pp.productid,
pp.name as nombre_juego ,
Case 
when ep.edicionproductid is null then ed.name
else pp.tipo_juego
end tipo_dejuego ,
     padre.name    as Cabeza
from Product.Product pp
left join Product.Product padre
on padre.productid = pp.juego_base
left join Product.EdicionProduct ep
on ep.edicionproductid = pp.productid
inner join Product.Edicion ed
on ep.edicionid = ed.edicionid
)
select productid, nombre_juego, tipo_dejuego, Cabeza ,
COALESCE(Cabeza, nombre_juego) AS GrupoOrden,
    CASE WHEN Cabeza IS NULL THEN 0 ELSE 1 END AS EsDLC
from catalago_juegos



/*
mostras los juegos con stock muy bajo (menos de 10 unidades)
VISTA
que hace: muestra el producto que tiene un stock menor a 10 unidades
NOMBRE: VW_Juegos_Stock_Bajo
HECHO POR: Alain Flores
FECHA: 26/06/2024
*/

Create or alter View VW_Juegos_Stock_Bajo as
select Coalesce(dlc.name,juegos.name) as nombre_juego , Coalesce(dlc.tipo_juego,juegos.tipo_juego) as tipo_juego, coalesce(ed.name,'sin edicion') as edicion, PI.cantidad as cantidad_stock
from Product.Inventario PI
--dlcs - complementos
left join Product.Product dlc
on PI.productid = dlc.productid
-- juegos base
left join Product.EdicionProduct ep
on ep.edicionproductid = pi.edicionproductid
left join product.Product juegos
on juegos.productid = ep.productid
left join Product.Edicion ed
on ed.edicionid = ep.edicionid
where PI.cantidad < 10

/*
VISTA 

Que hace : Muestra los ingresos totales  por cada juego (incluyendo DLCS) 
NOMBRE: VW_Ingresos_Por_Juego
HECHO POR: Alain Flores
FECHA: 26/06/2024

*/

select * from Venta.PedidoDetalles

Create or alter View VW_Ingresos_Por_Juego as
select  Coalesce(dlc.name,juegos.name) as nombre_juego , Coalesce(dlc.tipo_juego,juegos.tipo_juego) as tipo_juego,
  Sum(vpd.precio_prod*vpd.cantidad_pedida) as ingresos_totales
from Venta.Pedido vp 
inner join Venta.PedidoDetalles vpd
on vp.pedido_id= vpd.pedido_id
left join Product.Product dlc
on vpd.productoid = dlc.productid
left join Product.EdicionProduct ep
on ep.edicionproductid = vpd.edicionproductid
left join product.Product juegos
on juegos.productid = ep.productid
group by Coalesce(dlc.name,juegos.name) , Coalesce(dlc.tipo_juego,juegos.tipo_juego)


