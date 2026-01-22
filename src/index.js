require("dotenv").config();

const express = require("express");
const app = express();

app.use(express.json());

// Health check / public endpoint (NO AUTH)
app.get("/api/public/hello", (req, res) => {
    res.json({ message: "hello" });
});

const port = process.env.PORT || 5001;
app.listen(port, () => {
    console.log(`API running on http://localhost:${port}`);
});
