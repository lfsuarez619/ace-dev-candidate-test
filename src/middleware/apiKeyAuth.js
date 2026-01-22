function apiKeyAuth(req, res, next) {
    const key = req.header("x-api-key");
    const validKey = process.env.API_KEY;

    if (!key || !validKey || key !== validKey) {
        return res.status(401).json({ message: "Unauthorized" });
    }

    next();
}

module.exports = { apiKeyAuth };
