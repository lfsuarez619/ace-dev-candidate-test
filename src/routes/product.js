const express = require("express");
const { viewAllProducts } = require("../controllers/productController");
const router = express.Router();

router.get("/viewall", viewAllProducts);

module.exports = router;
