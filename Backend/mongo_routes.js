const express = require('express');
const router = express.Router();

const ComentarioProducto = require('./models/ComentarioProducto');
const PlaylistCliente = require('./models/PlaylistCliente');

// ==========================================
// RUTAS PARA COMENTARIOS DE PRODUCTOS
// ==========================================

// Obtener comentarios de un producto específico
router.get('/comentarios/:productId', async (req, res) => {
    try {
        const comentarios = await ComentarioProducto.find({ productId: req.params.productId })
            .sort({ createdAt: -1 }); // Los más recientes primero
        res.json(comentarios);
    } catch (error) {
        console.error('Error al obtener comentarios:', error);
        res.status(500).json({ error: 'Error al obtener comentarios' });
    }
});

// Crear un nuevo comentario
router.post('/comentarios', async (req, res) => {
    try {
        const { productId, clienteId, autor, gmail, comentario } = req.body;
        
        if (!productId || !clienteId || !autor || !gmail || !comentario) {
            return res.status(400).json({ error: 'Todos los campos son requeridos' });
        }

        const nuevoComentario = new ComentarioProducto({
            productId,
            clienteId,
            autor,
            gmail,
            comentario
        });

        await nuevoComentario.save();
        res.status(201).json(nuevoComentario);
    } catch (error) {
        console.error('Error al crear comentario:', error);
        res.status(500).json({ error: 'Error al guardar el comentario' });
    }
});

// ==========================================
// RUTAS PARA PLAYLISTS DE CLIENTES
// ==========================================

// Obtener la playlist de un cliente
router.get('/playlists/:clienteId', async (req, res) => {
    try {
        let playlist = await PlaylistCliente.findOne({ id_cliente: req.params.clienteId });
        if (!playlist) {
            return res.json({ error: 'Playlist no encontrada' });
        }
        res.json(playlist);
    } catch (error) {
        console.error('Error al obtener playlist:', error);
        res.status(500).json({ error: 'Error al obtener playlist' });
    }
});

// Crear o actualizar la playlist
router.post('/playlists', async (req, res) => {
    try {
        const { id_cliente, nombre, email, Comentario, listaproductos } = req.body;
        
        if (!id_cliente || !nombre || !Comentario || !listaproductos) {
            return res.status(400).json({ error: 'Faltan campos requeridos para la playlist' });
        }

        // Buscamos si ya tiene una playlist
        let playlist = await PlaylistCliente.findOne({ id_cliente: id_cliente });

        if (playlist) {
            // Actualizamos
            playlist.nombre = nombre;
            playlist.email = email;
            playlist.Comentario = Comentario;
            playlist.listaproductos = listaproductos;
            await playlist.save();
        } else {
            // Creamos nueva
            playlist = new PlaylistCliente({
                id_cliente,
                nombre,
                email,
                Comentario,
                listaproductos
            });
            await playlist.save();
        }

        res.status(200).json(playlist);
    } catch (error) {
        console.error('Error al guardar playlist:', error);
        res.status(500).json({ error: 'Error al guardar la playlist' });
    }
});

// Eliminar un producto de la playlist
router.delete('/playlists/:clienteId/productos/:productId', async (req, res) => {
    try {
        const { clienteId, productId } = req.params;
        let playlist = await PlaylistCliente.findOne({ id_cliente: clienteId });
        
        if (!playlist) {
            return res.status(404).json({ error: 'Playlist no encontrada' });
        }

        playlist.listaproductos = playlist.listaproductos.filter(p => p.productId != productId);
        await playlist.save();
        
        res.json(playlist);
    } catch (error) {
        console.error('Error al eliminar producto de playlist:', error);
        res.status(500).json({ error: 'Error al eliminar producto' });
    }
});

module.exports = router;
