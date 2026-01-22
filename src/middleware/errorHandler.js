function notFound(req, res) {
    res.status(404).json({ message: "Not Found" });
}

function errorHandler(err, req, res, next) {
    // Do not expose internal details
    console.error(err);

    if (res.headersSent) return next(err);

    const status = err.statusCode || 500;
    const message = status === 500 ? "Internal Server Error" : err.message;

    res.status(status).json({ message });
}

module.exports = { notFound, errorHandler };
