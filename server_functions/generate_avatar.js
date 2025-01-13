const { createCanvas } = require('canvas');

function generateAvatar(userName) {
    const canvas = createCanvas(200, 200);
    const ctx = canvas.getContext('2d');

    ctx.fillStyle = '#3498db';
    ctx.fillRect(0, 0, canvas.width, canvas.height);

    ctx.fillStyle = '#ffffff';
    ctx.font = 'bold 73px Arial';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';

    const firstLetter = userName.charAt(0).toUpperCase();

    ctx.fillText(firstLetter, canvas.width / 2, canvas.height / 2);

    return canvas.toBuffer('image/png');
}

module.exports = {
    generateAvatar,
}