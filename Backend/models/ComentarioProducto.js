const mongoose = require('mongoose');

// Corresponde a la captura de pantalla de "Playlist"
const comentarioProductoSchema = new mongoose.Schema({
    productId: {
        type: Number,
        required: true,
        description: 'ID del producto en SQL Server'
    },
    clienteId: {
        type: Number,
        required: true,
        description: 'ID del cliente en SQL Server'
    },
    autor: {
        type: String,
        required: true,
        description: 'Nombre del autor'
    },
    gmail: {
        type: String,
        required: true,
        description: 'Por si el nombre es igual al de otra persona'
    },
    comentario: {
        type: String,
        required: true,
        minLength: 1,
        description: 'Texto del comentario'
    },
    likes: [{
        type: Number,
        description: 'Arreglo de IDs de clientes que dieron Like'
    }],
    dislikes: [{
        type: Number,
        description: 'Arreglo de IDs de clientes que dieron Dislike'
    }]
}, { timestamps: true });

module.exports = mongoose.model('ComentarioProducto', comentarioProductoSchema, 'ComentariosDeProductos');
