const { getPool } = require("../db/pool");

async function viewAllProducts(req, res, next) {
    try {
        const pool = await getPool();
        const result = await pool.request().execute("dbo.uspProduct_GetAll");
        res.json(result.recordset);
    } catch (err) {
        next(err);
    }
}

module.exports = { viewAllProducts };
