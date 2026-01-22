const sql = require("mssql");

let pool;

/**
 * Create and reuse a single pool across the app (best practice).
 */
async function getPool() {
    if (pool) return pool;

    const config = {
        server: process.env.DB_SERVER,
        port: Number(process.env.DB_PORT || 1433),
        database: process.env.DB_DATABASE,
        user: process.env.DB_USER,
        password: process.env.DB_PASSWORD,
        options: {
            encrypt: false,
            trustServerCertificate: true, // for local Docker
        },
    };

    pool = await sql.connect(config);
    return pool;
}

module.exports = { getPool, sql };
