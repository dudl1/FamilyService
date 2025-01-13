const configureServerTimeouts = (server) => {
    server.headersTimeout = 60000 // Максимальное время ожидания заголовков запроса (60 секунд)
    server.requestTimeout = 60000 // Максимальное время ожидания завершения запроса (60 секунд)
    server.timeout = 120000 // Максимальное время бездействующего соединения (2 минуты)
    server.keepAliveTimeout = 5000 // Время ожидания для keep-alive соединений (5 секунд)
}

module.exports = {
    configureServerTimeouts,
}