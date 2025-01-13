const express = require('express');
const sqlite3 = require('sqlite3').verbose();
const { exec } = require('child_process');
const { configureHelmet, configureRateLimiting } = require('./server_helper/security.js');
const { handleUncaughtExceptions } = require('./server_helper/errorHandler.js');
const { configureServerTimeouts } = require('./server_helper/serverConfig.js');
const { v4: uuidv4 } = require('uuid');
const { generateAvatar } = require('./server_functions/generate_avatar.js');
const fs = require('fs');
const path = require('path');
const busboy = require('busboy');

const app = express();
const PORT = 8080;

configureHelmet(app)
configureRateLimiting(app)

app.use('/uploads', express.static(path.join('F:/DATA/files', 'uploads')));

const db_users_path = 'F:/DATA/users/users.db'
const db_users = new sqlite3.Database(db_users_path, (err) => {
  if (err) {
    console.error('Ошибка подключения к базе данных USERS:', err.message)
  } else {
    console.log('Подключено к базе данных USERS')
  }
})

db_users.run(
  `CREATE TABLE IF NOT EXISTS users (
    user_id TEXT PRIMARY KEY,
    user_name TEXT NOT NULL,
    avatar BLOB,
    created_at TEXT NOT NULL
  )`
)

const db_files_path = 'F:/DATA/files/files.db'
const db_files = new sqlite3.Database(db_files_path, (err) => {
  if (err) {
    console.error('Ошибка подключения к базе данных FILES:', err.message)
  } else {
    console.log('Подключено к базе данных FILES')
  }
})

db_files.run(
  `CREATE TABLE IF NOT EXISTS files (
    file_id TEXT PRIMARY KEY,
    file_from TEXT NOT NULL,
    file_created TEXT NOT NULL,
    file_type TEXT NOT NULL,
    file_path TEXT NOT NULL,
    FOREIGN KEY(file_from) REFERENCES users(user_id)
  )`
)



app.get('/auth', (req, res) => { // http://localhost:8080/auth?user_name=NAME
    const { user_name } = req.query;

    if (!user_name) {
        return res.status(400).send('Имя пользователя не может быть пустым');
    }

    const checkUserQuery = 'SELECT * FROM users WHERE user_name = ?';
    db_users.get(checkUserQuery, [user_name], (err, row) => {
        if (err) {
            return res.status(500).send('Ошибка при проверке пользователя');
        }

        if (row) {
            return res.status(400).send('Пользователь с таким именем уже существует');
        }

        const userId = uuidv4();
        const avatarBuffer = generateAvatar(user_name);
        const createdAt = new Date().toISOString();

        const insertUserQuery = 'INSERT INTO users (user_id, user_name, avatar, created_at) VALUES (?, ?, ?, ?)';
        
        db_users.run(insertUserQuery, [userId, user_name, avatarBuffer, createdAt], function (err) {
            if (err) {
                return res.status(500).send('Ошибка при добавлении пользователя');
            }

            const response_json = {
                "user_id": userId,
                "avatar": avatarBuffer,
                "created_at": createdAt
            }
            res.status(201).send(response_json);
        });
    });
});

app.get('/users', (req, res) => {
    const query = 'SELECT * FROM users';
    db_users.all(query, [], (err, rows) => {
        if (err) {
            return res.status(500).send('Ошибка при получении пользователей');
        }
        res.status(200).json(rows);
    });
});

app.get('/disk-info', (req, res) => {
    exec('wmic logicaldisk where "DeviceID=\'F:\'" get FreeSpace,Size', (err, stdout, stderr) => {
        if (err || stderr) {
            return res.status(500).send('Ошибка при получении информации о диске.');
        }

        const lines = stdout.split('\n');
        const diskInfo = lines[1].trim().split(/\s+/);

        const freeSpace = Math.round(parseInt(diskInfo[0], 10) / (1024 ** 3));
        const totalSpace = Math.round(parseInt(diskInfo[1], 10) / (1024 ** 3));
        const usedSpace = totalSpace - freeSpace;

        res.status(200).json({
            totalSpace,
            freeSpace,
            usedSpace
        });
    });
});

app.post('/upload', (req, res) => {
    let userId;
    let fileType;
  
    const bb = busboy({ headers: req.headers });
  
    bb.on('field', (name, val) => {
      if (name === 'user_id') {
        userId = val;
        console.log(`Извлечён user_id: ${userId}`);
      }
      if (name === 'file_type') {
        fileType = val;
        console.log(`Извлечён file_type: ${fileType}`);
      }
    });
  
    bb.on('file', (fieldname, file, filename, encoding, mimetype) => {
      const uniqueName = `${uuidv4()}.jpg`;
      const uploadsDir = path.join('F:/DATA/files', 'uploads');
  
      if (!fs.existsSync(uploadsDir)) {
        fs.mkdirSync(uploadsDir);
      }
  
      const filePath = path.join(uploadsDir, uniqueName);
      const writeStream = fs.createWriteStream(filePath);
  
      file.pipe(writeStream);
  
      writeStream.on('finish', () => {
        console.log(`Сохраняю файл: ${filePath}`);
  
        const fileCreated = new Date().toISOString();
        const fileId = uuidv4();
  
        if (!userId) {
          return res.status(400).json({ error: 'user_id is missing' });
        }
  
        const query = `
          INSERT INTO files (file_id, file_from, file_created, file_type, file_path)
          VALUES (?, ?, ?, ?, ?)
        `;
        
        db_files.run(query, [fileId, userId, fileCreated, fileType, filePath], (err) => {
          if (err) {
            console.error('Ошибка при записи в базу данных FILES:', err.message);
            return res.status(500).json({ error: 'Ошибка при сохранении файла' });
          }
          console.log('Информация о файле успешно добавлена в базу данных');
          res.status(200).json({ message: 'Файл успешно загружен и сохранен в базе данных' });
        });
      });
    });
  
    req.pipe(bb);  // Запускаем обработку данных
});

app.get('/api/files', (req, res) => {
  const query = 'SELECT file_id, file_path, file_type FROM files';
  db_files.all(query, (err, rows) => {
    if (err) {
      console.error('Ошибка при получении файлов из базы данных:', err.message);
      return res.status(500).json({ error: 'Ошибка при получении файлов' });
    }
    
    rows = rows.map(row => ({
      ...row,
      file_path: `https://f579-154-47-24-154.ngrok-free.app/uploads/${path.basename(row.file_path)}`
    }));
    res.json(rows);
  });
});



app.use((req, res) => {
    res.status(404).send('Неверная запись!');
});

const server = app.listen(PORT, () => {
    console.log(`Сервер запущен на http://localhost:${PORT}`);
});


// Настройка таймаутов сервера
configureServerTimeouts(server);
// Обработка необработанных исключений
handleUncaughtExceptions(server);