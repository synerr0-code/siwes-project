// server.js
const express = require('express');
const os = require('os');
const app = express();

// --- UPDATE THESE VARIABLES TO TEST BLUE/GREEN DEPLOYMENTS ---
const APP_VERSION = "v1.0.0";
const ENVIRONMENT_NAME = "BLUE ENVIRONMENT"; // Change to "GREEN ENVIRONMENT"
const THEME_COLOR = "#006eff";             // Blue: #006eff | Green: #10b981
const THEME_DARK = "#0047ab";              // Blue: #0047ab | Green: #047857

// ALB Health Check Endpoint
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    version: APP_VERSION,
    instance: os.hostname(),
    uptime: process.uptime()
  });
});

// Main Application Dashboard
app.get('/', (req, res) => {
  // Simulates processing time to prove zero dropped requests during traffic shifts
  setTimeout(() => {
    const uptimeSeconds = Math.floor(process.uptime());
    const requestTime = new Date().toUTCString();

    res.send(`
      <!DOCTYPE html>
      <html lang="en">
      <head>
        <meta charset="UTF-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0" />
        <title>SIWES Blue/Green Deployment | ${APP_VERSION}</title>
        <style>
          * {
            box-sizing: border-box;
            margin: 0;
            padding: 0;
          }
          body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
            background: linear-gradient(135deg, ${THEME_COLOR} 0%, ${THEME_DARK} 100%);
            color: #ffffff;
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 24px;
          }
          .card {
            background: rgba(15, 23, 42, 0.78);
            backdrop-filter: blur(12px);
            border: 1px solid rgba(255, 255, 255, 0.18);
            border-radius: 16px;
            max-width: 680px;
            width: 100%;
            padding: 36px;
            box-shadow: 0 20px 45px rgba(0, 0, 0, 0.35);
          }
          .header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            flex-wrap: wrap;
            gap: 12px;
            margin-bottom: 24px;
          }
          .badge {
            background-color: ${THEME_COLOR};
            color: #ffffff;
            font-size: 0.78rem;
            font-weight: 700;
            letter-spacing: 0.08em;
            padding: 6px 14px;
            border-radius: 999px;
            text-transform: uppercase;
            box-shadow: 0 0 15px rgba(255, 255, 255, 0.25);
          }
          .status {
            display: flex;
            align-items: center;
            gap: 8px;
            font-size: 0.88rem;
            color: #cbd5e1;
          }
          .dot {
            width: 10px;
            height: 10px;
            background-color: #22c55e;
            border-radius: 50%;
            box-shadow: 0 0 8px #22c55e;
          }
          h1 {
            font-size: 1.85rem;
            font-weight: 700;
            margin-bottom: 10px;
            letter-spacing: -0.02em;
          }
          .subtitle {
            color: #cbd5e1;
            font-size: 0.98rem;
            line-height: 1.55;
            margin-bottom: 28px;
          }
          .grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
            gap: 16px;
            margin-bottom: 28px;
          }
          .metric {
            background: rgba(255, 255, 255, 0.06);
            border: 1px solid rgba(255, 255, 255, 0.1);
            border-radius: 10px;
            padding: 16px;
          }
          .metric-label {
            font-size: 0.75rem;
            text-transform: uppercase;
            letter-spacing: 0.06em;
            color: #94a3b8;
            margin-bottom: 6px;
          }
          .metric-value {
            font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
            font-size: 1.05rem;
            font-weight: 600;
            color: #f8fafc;
            word-break: break-all;
          }
          .footer {
            border-top: 1px solid rgba(255, 255, 255, 0.12);
            padding-top: 18px;
            display: flex;
            justify-content: space-between;
            flex-wrap: wrap;
            gap: 10px;
            font-size: 0.82rem;
            color: #94a3b8;
          }
        </style>
      </head>
      <body>
        <div class="card">
          <div class="header">
            <span class="badge">${ENVIRONMENT_NAME}</span>
            <div class="status">
              <span class="dot"></span>
              <span>ALB Target Healthy</span>
            </div>
          </div>

          <h1>Zero-Downtime Immutable Deployment</h1>
          <p class="subtitle">
            Automated CI/CD infrastructure provisioned with <strong>Packer</strong>, <strong>Terraform</strong>, and <strong>GitHub Actions</strong> behind an AWS Application Load Balancer.
          </p>

          <div class="grid">
            <div class="metric">
              <div class="metric-label">Release Version</div>
              <div class="metric-value">${APP_VERSION}</div>
            </div>
            <div class="metric">
              <div class="metric-label">EC2 Instance Hostname</div>
              <div class="metric-value">${os.hostname()}</div>
            </div>
            <div class="metric">
              <div class="metric-label">Process Uptime</div>
              <div class="metric-value">${uptimeSeconds}s (PM2 Managed)</div>
            </div>
            <div class="metric">
              <div class="metric-label">Runtime & Architecture</div>
              <div class="metric-value">Node ${process.version} (${os.arch()})</div>
            </div>
          </div>

          <div class="footer">
            <span>Health Endpoint: <code>/health</code> (HTTP 200)</span>
            <span>Served: ${requestTime}</span>
          </div>
        </div>
      </body>
      </html>
    `);
  }, 200);
});

const server = app.listen(3000, () => {
  console.log(`[${ENVIRONMENT_NAME}] Running version ${APP_VERSION} on port 3000`);
});

// Graceful connection draining when Auto Scaling terminates old instances
process.on('SIGINT', () => {
  console.log('SIGINT received: Draining active connections before shutdown...');
  server.close(() => {
    console.log('All connections closed. Exiting cleanly.');
    process.exit(0);
  });
});