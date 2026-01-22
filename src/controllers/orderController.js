const { getPool, sql } = require("../db/pool");

function badRequest(message) {
    const err = new Error(message);
    err.statusCode = 400;
    return err;
}

function notFound(message) {
    const err = new Error(message);
    err.statusCode = 404;
    return err;
}

function isGuid(s) {
    return typeof s === "string" &&
        /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/.test(s);
}


async function viewAllOrders(req, res, next) {
    try {
        const pool = await getPool();
        const result = await pool.request().execute("dbo.uspOrder_GetAll");
        res.json(result.recordset);
    } catch (err) {
        next(err);
    }
}

/**
 * GET /api/order/vieworderdetail
 * Reference shape:
 * [
 *   { customerDetail: {...}, orderDetail: {...}, lineItems: [...] },
 *   ...
 * ]
 */
async function viewAllOrdersWithDetails(req, res, next) {
    try {
        const pool = await getPool();
        const result = await pool.request().execute("dbo.uspOrder_GetAllInvoiceDetails_Flat");
        const rows = result.recordset || [];

        const byInvoice = new Map();

        for (const r of rows) {
            const invoiceNumber = r.invoiceNumber;

            if (!byInvoice.has(invoiceNumber)) {
                byInvoice.set(invoiceNumber, {
                    customerDetail: {
                        customerId: r.customerId,
                        customerName: r.customerName,
                        customerAddress1: r.customerAddress1,
                        customerAddress2: r.customerAddress2,
                        customerCity: r.customerCity,
                        customerState: r.customerState,
                        customerPostalCode: r.customerPostalCode,
                        customerTelephone: r.customerTelephone,
                        customerContactName: r.customerContactName,
                        customerEmailAddress: r.customerEmailAddress,
                    },
                    orderDetail: {
                        invoiceNumber: r.invoiceNumber,
                        invoiceDate: r.invoiceDate,
                        // some flat procs include orderCustomerId; fall back to customerId
                        customerId: r.orderCustomerId || r.customerId,
                    },
                    lineItems: [],
                });
            }

            // Only push a line item if we actually have one (LEFT JOIN can produce nulls)
            if (r.lineItemId) {
                byInvoice.get(invoiceNumber).lineItems.push({
                    lineItemId: r.lineItemId,
                    productId: r.productId,
                    quantity: r.quantity,
                    invoiceDate: r.invoiceDate,
                    productName: r.productName,
                    productCost: r.productCost,
                    totalCost: r.totalCost,
                });
            }
        }

        // Reference appears ordered by invoiceNumber ascending
        const payload = Array.from(byInvoice.values()).sort(
            (a, b) => a.orderDetail.invoiceNumber - b.orderDetail.invoiceNumber
        );

        res.json(payload);
    } catch (err) {
        next(err);
    }
}

/**
 * GET /api/order/details/:invoiceNumber
 * Calls dbo.uspOrder_GetInvoiceDetails which returns 3 resultsets:
 *  1) customerDetail (1 row)
 *  2) orderDetail (1 row)
 *  3) lineItems (0+ rows; may contain one null row due to LEFT JOIN)
 */
async function getOrderDetails(req, res, next) {
    try {
        const invoiceNumber = Number(req.params.invoiceNumber);
        if (!Number.isInteger(invoiceNumber) || invoiceNumber <= 0) {
            throw badRequest("invoiceNumber must be a positive integer");
        }

        const pool = await getPool();
        const result = await pool
            .request()
            .input("invoiceNumber", sql.Int, invoiceNumber)
            .execute("dbo.uspOrder_GetInvoiceDetails");

        const customerDetail = result.recordsets?.[0]?.[0] || null;
        const orderDetail = result.recordsets?.[1]?.[0] || null;

        // Filter out null “line item” row (common when LEFT JOIN returns no items)
        const rawLineItems = result.recordsets?.[2] || [];
        const lineItems = rawLineItems.filter((li) => li && li.lineItemId);

        if (!customerDetail || !orderDetail) {
            throw notFound("Order not found");
        }

        res.json({ customerDetail, orderDetail, lineItems });
    } catch (err) {
        next(err);
    }
}

/**
 * POST /api/order/new
 * Expecting request body like the example:
 * {
 *   "customerId": "<guid>",
 *   "invoiceDate": "2024-12-20T14:30:00", (optional)
 *   "lineItems": [{ "productId": "<guid>", "quantity": 2 }, ...]
 * }
 *
 * We also accept "items" as a fallback to make debugging easier.
 */
async function createOrder(req, res, next) {
    try {
        // Support the example/Postman shape:
        // {
        //   invoiceData: { invoiceDate, customerId },
        //   products: [{ productId, quantity }]
        // }
        const invoiceData = req.body.invoiceData || {};

        const customerId = req.body.customerId || invoiceData.customerId;
        const invoiceDateRaw = req.body.invoiceDate || invoiceData.invoiceDate;

        // "products" in the example == line items
        const products =
            req.body.products ||
            req.body.lineItems ||
            req.body.items;

        if (!isGuid(customerId)) {
            throw badRequest("customerId must be a GUID");
        }

        if (!Array.isArray(products) || products.length === 0) {
            throw badRequest("products must be a non-empty array");
        }

        for (const p of products) {
            if (!isGuid(p.productId)) {
                throw badRequest("Each products[].productId must be a GUID");
            }
            if (!Number.isInteger(p.quantity) || p.quantity <= 0) {
                throw badRequest("Each products[].quantity must be a positive integer");
            }
        }

        // invoiceDate is optional; if present, validate it
        let invoiceDateValue = null;
        if (invoiceDateRaw !== undefined && invoiceDateRaw !== null && invoiceDateRaw !== "") {
            const d = new Date(invoiceDateRaw);
            if (Number.isNaN(d.getTime())) {
                throw badRequest("invoiceDate must be a valid date string");
            }
            invoiceDateValue = d;
        }

        const itemsJson = JSON.stringify(
            products.map((p) => ({ productId: p.productId, quantity: p.quantity }))
        );

        const pool = await getPool();

        const request = pool
            .request()
            .input("customerId", sql.UniqueIdentifier, customerId)
            .input("itemsJson", sql.NVarChar(sql.MAX), itemsJson);

        if (invoiceDateValue) {
            request.input("invoiceDate", sql.DateTime2, invoiceDateValue);
        }

        const result = await request.execute("dbo.uspOrder_Create");
        const invoiceNumber = result.recordset?.[0]?.invoiceNumber;

        // Match the reference behavior you observed
        res.status(200).send(`New Invoice Added: ${invoiceNumber}`);
    } catch (err) {
        // Map SQL "does not exist" to 400
        if (!err.statusCode && typeof err.message === "string" && err.message.toLowerCase().includes("does not exist")) {
            err.statusCode = 400;
        }
        next(err);
    }
}

module.exports = {
    viewAllOrders,
    viewAllOrdersWithDetails,
    getOrderDetails,
    createOrder,
};
