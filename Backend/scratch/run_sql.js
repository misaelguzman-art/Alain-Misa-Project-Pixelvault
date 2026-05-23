const fs = require('fs');
const path = require('path');
const { poolBolivia, poolPeru, sql } = require('../database');

// Obtener el tipo de nodo desde la consola (ej: 'node scratch/run_sql.js bolivia' o 'node scratch/run_sql.js peru')
const targetNode = process.argv[2] ? process.argv[2].toLowerCase() : null;

if (!targetNode || (targetNode !== 'bolivia' && targetNode !== 'peru')) {
    console.error('❌ Debes especificar el nodo objetivo: "node scratch/run_sql.js bolivia" o "node scratch/run_sql.js peru"');
    process.exit(1);
}

const pool = targetNode === 'peru' ? poolPeru : poolBolivia;
const sqlFilePath = path.join(__dirname, '..', 'BD', 'cambios_mejoras.sql');

async function run() {
    console.log(`🚀 Iniciando aplicación de mejoras SQL para el nodo: ${targetNode.toUpperCase()}`);
    console.log(`Reading SQL file from: ${sqlFilePath}`);
    
    if (!fs.existsSync(sqlFilePath)) {
        throw new Error(`El archivo de mejoras no existe en la ruta: ${sqlFilePath}`);
    }
    
    const sqlText = fs.readFileSync(sqlFilePath, 'utf8');

    // Separar script por el comando GO (insensible a mayúsculas, en su propia línea)
    const batches = sqlText.split(/^\s*GO\s*$/mi);

    console.log(`Parsed ${batches.length} SQL batches to execute.`);
    
    console.log(`Connecting to SQL Server pool for ${targetNode.toUpperCase()}...`);
    if (!pool.connected) {
        await pool.connect();
    }
    console.log('✅ Connected successfully.');

    for (let i = 0; i < batches.length; i++) {
        const batch = batches[i].trim();
        if (!batch) continue;

        console.log(`\nExecuting batch ${i + 1}/${batches.length}...`);
        const firstLine = batch.split('\n')[0].substring(0, 80);
        console.log(`Snippet: ${firstLine}...`);

        try {
            await pool.request().query(batch);
            console.log(`✅ Batch ${i + 1} executed successfully.`);
        } catch (err) {
            console.error(`❌ Error in batch ${i + 1}:`, err.message);
            console.log('--- Batch Content ---');
            console.log(batch);
            console.log('---------------------');
            throw err;
        }
    }

    console.log(`\n🎉 ¡Todas las mejoras SQL fueron aplicadas con éxito en ${targetNode.toUpperCase()}!`);
    await sql.close();
}

run().catch(err => {
    console.error('Fatal execution error:', err);
    sql.close();
    process.exit(1);
});
