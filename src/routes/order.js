const express = require("express");
const {
    viewAllOrders,
    viewAllOrdersWithDetails,
    getOrderDetails,
    createOrder,
} = require("../controllers/orderController");

const router = express.Router();

router.get("/viewall", viewAllOrders);
router.get("/vieworderdetail", viewAllOrdersWithDetails);
router.get("/details/:invoiceNumber", getOrderDetails);
router.post("/new", createOrder);

module.exports = router;
