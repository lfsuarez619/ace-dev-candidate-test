const express = require("express");
const { viewAllCustomers } = require("../controllers/customerController");
const router = express.Router();

router.get("/viewall", viewAllCustomers);

module.exports = router;
