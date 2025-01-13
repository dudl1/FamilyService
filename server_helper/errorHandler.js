const handleUncaughtExceptions = (server) => {
    process.on('uncaughtException', (err) => {
        console.error('Необработанное исключение:', err)
        server.close(() => {
            process.exit(1)
        })
        setTimeout(() => {
            process.abort()
        }, 1000).unref()
    })

    process.on('unhandledRejection', (reason, promise) => {
        console.error('Необработанное отклонение промиса:', promise, 'Причина:', reason)
    })
}

module.exports = {
    handleUncaughtExceptions,
}