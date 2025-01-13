const helmet = require('helmet')
const rateLimit = require('express-rate-limit')

const configureHelmet = (app) => {
    app.use(helmet())
}

const configureRateLimiting = (app) => {
    const limiter = rateLimit({
        windowMs: 1 * 60 * 1000, // 1 мин
        max: 200,
        standardHeaders: true, // Возвращает информацию об ограничении в заголовках `RateLimit-*`
        legacyHeaders: false, // Отключает заголовки `X-RateLimit-*`
    })
    app.use(limiter)
}

module.exports = {
    configureHelmet,
    configureRateLimiting,
}