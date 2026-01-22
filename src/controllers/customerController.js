const { getPool } = require("../db/pool");

async function viewAllCustomers(req, res, next) {
    try {
        const pool = await getPool();
        const result = await pool.request().execute("dbo.uspCustomer_GetAll");
        res.json(result.recordset); // camelCase depends on your proc column names
    } catch (err) {
        next(err);
    }
}

module.exports = { viewAllCustomers };
