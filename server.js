// server.js
const express = require('express');
const os = require('os');
const app = express();

// --- CHANGE THESE TWO VARIABLES FOR EVERY DEPLOYMENT ---
const APP_VERSION = "v1.2.1"; 
const BACKGROUND_COLOR = "#11ff00"; // Blue. (Change to #28a745 for Green)

app.get('/health', (req, res) => res.status(200).send('OK'));

app.get('/', (req, res) => {
  // Simulating some processing time to prove connections don't drop
  setTimeout(() => {
    res.send(`
      <body style="background-color: ${BACKGROUND_COLOR}; color: white; text-align: center; font-family: sans-serif; padding-top: 10%;">
        <h1>SIWES Blue/Green Deployment</h1>
        <h2>Version: ${APP_VERSION}</h2>
        <p>Served by EC2 Instance: <strong>${os.hostname()}</strong></p>
      </body>
    `);
  }, 200); 
});

const server = app.listen(3000, () => console.log(`Running version ${APP_VERSION}`));

process.on('SIGINT', () => {
  console.log('Draining connections...');
  server.close(() => process.exit(0));
});