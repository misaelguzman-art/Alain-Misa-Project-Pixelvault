const mongoose = require('mongoose');

// Corresponde a la captura de pantalla de "Comentarios"
const playlistClienteSchema = new mongoose.Schema({
    id_cliente: {
        type: Number,
        required: true
    },
    nombre: {
        type: String,
        required: true
    },
    email: {
        type: String
    },
    Comentario: {
        type: String,
        required: true,
        minLength: 1
    },
    listaproductos: {
        type: [{
            productId: { type: Number, required: true },
            nombre: { type: String },
            imagen: { type: String },
            precio: { type: Number }
        }],
        required: true
    }
}, { timestamps: true });

module.exports = mongoose.model('PlaylistCliente', playlistClienteSchema, 'PlaylistsDeClientes');
