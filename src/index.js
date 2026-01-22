require("dotenv").config();

const express = require("express");
const { apiKeyAuth } = require("./middleware/apiKeyAuth");
const { notFound, errorHandler } = require("./middleware/errorHandler");

const publicRoutes = require("./routes/public");
const customerRoutes = require("./routes/customer");
const productRoutes = require("./routes/product");
const orderRoutes = require("./routes/order");

const app = express();
app.use(express.json());

// No-auth route
app.use("/api/public", publicRoutes);

// Auth required for everything else
app.use("/api/customer", apiKeyAuth, customerRoutes);
app.use("/api/product", apiKeyAuth, productRoutes);
app.use("/api/order", apiKeyAuth, orderRoutes);

app.use(notFound);
app.use(errorHandler);

const port = process.env.PORT || 5001;
app.listen(port, () => console.log(`API running on http://localhost:${port}`));
