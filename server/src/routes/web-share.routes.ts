import { Router } from 'express';
import crypto from 'crypto';
import { prisma } from '../db';

export const webShareRouter = Router();

function hashToken(token: string) {
  return crypto.createHash('sha256').update(token).digest('hex');
}

function escapeHtml(unsafe: string | null | undefined) {
  if (!unsafe) return '';
  return String(unsafe)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

function formatTime(dateString: Date) {
  return new Date(dateString).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
}

webShareRouter.get('/:token', async (req, res, next) => {
  try {
    const token = req.params.token;
    if (!token || typeof token !== 'string') {
      return res.status(404).send('<h1>404 - Invalid Link</h1><p>Share link is missing or invalid.</p>');
    }

    const share = await prisma.teamShare.findFirst({
      where: {
        tokenHash: hashToken(token),
        revokedAt: null,
        expiresAt: { gt: new Date() }
      }
    });

    if (!share) {
      return res.status(404).send(`
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>Equilibrium - Link Expired</title>
          <style>
            body { font-family: system-ui, -apple-system, sans-serif; background-color: #0A1628; color: #FFFFFF; text-align: center; padding: 40px 20px; }
            .container { max-width: 600px; margin: 0 auto; background-color: #122238; padding: 40px; border-radius: 12px; }
            h1 { color: #E53935; }
            p { color: #A0B3C6; }
          </style>
        </head>
        <body>
          <div class="container">
            <h1>Link Expired or Invalid</h1>
            <p>This read-only schedule link is no longer active.</p>
          </div>
        </body>
        </html>
      `);
    }

    const schedule = await prisma.scheduleVersion.findFirst({
      where: { userId: share.userId },
      orderBy: { generatedAt: 'desc' },
      select: {
        id: true,
        generatedAt: true,
        capacityMinutes: true,
        algorithmVersion: true,
        blocks: {
          orderBy: { startTime: 'asc' },
          select: {
            id: true,
            taskId: true,
            startTime: true,
            endTime: true,
            durationMinutes: true,
            blockType: true,
            task: { select: { title: true, cognitiveLoad: true } }
          }
        }
      }
    });

    if (!schedule) {
      return res.status(404).send('<h1>404 - Schedule Not Found</h1><p>No schedule was found for this user.</p>');
    }

    let blocksHtml = '';
    
    if (schedule.blocks.length === 0) {
      blocksHtml = '<div class="empty-state">No tasks or commitments scheduled.</div>';
    } else {
      schedule.blocks.forEach(block => {
        let title = '';
        let typeClass = '';
        if (block.blockType === 'SLEEP') {
          title = 'Sleep';
          typeClass = 'block-sleep';
        } else if (block.blockType === 'COMMITMENT') {
          title = 'Commitment'; // generic fallback
          typeClass = 'block-commitment';
        } else {
          title = block.task?.title || 'Task';
          typeClass = 'block-task';
        }

        const safeTitle = escapeHtml(title);
        const startTime = formatTime(block.startTime);
        const endTime = formatTime(block.endTime);
        const duration = block.durationMinutes;

        blocksHtml += `
          <div class="block ${typeClass}">
            <div class="block-time">${startTime} - ${endTime} <span class="duration">(${duration}m)</span></div>
            <div class="block-title">${safeTitle}</div>
          </div>
        `;
      });
    }

    const generatedAtStr = escapeHtml(new Date(schedule.generatedAt).toLocaleDateString(undefined, { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' }));
    const expiresAtStr = escapeHtml(new Date(share.expiresAt).toLocaleString());

    const html = `
      <!DOCTYPE html>
      <html lang="en">
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>Shared Schedule - Equilibrium</title>
        <style>
          :root {
            --bg-color: #0A1628;
            --card-bg: #122238;
            --text-main: #FFFFFF;
            --text-muted: #A0B3C6;
            --accent: #3B82F6;
            --sleep-bg: #1E3A8A;
            --task-bg: #1F2937;
            --commitment-bg: #065F46;
          }
          * { box-sizing: border-box; }
          body {
            font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            background-color: var(--bg-color);
            color: var(--text-main);
            margin: 0;
            padding: 20px;
            line-height: 1.5;
          }
          .container {
            max-width: 600px;
            margin: 0 auto;
          }
          .header {
            text-align: center;
            margin-bottom: 30px;
          }
          .header h1 {
            margin: 0 0 10px 0;
            font-size: 24px;
            color: var(--accent);
          }
          .badge-readonly {
            display: inline-block;
            background-color: rgba(255,255,255,0.1);
            color: var(--text-muted);
            padding: 4px 10px;
            border-radius: 12px;
            font-size: 12px;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            margin-bottom: 15px;
          }
          .meta-info {
            font-size: 14px;
            color: var(--text-muted);
          }
          .schedule-container {
            background-color: var(--card-bg);
            border-radius: 12px;
            padding: 20px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.3);
          }
          .block {
            padding: 15px;
            border-radius: 8px;
            margin-bottom: 10px;
            border-left: 4px solid transparent;
          }
          .block:last-child { margin-bottom: 0; }
          .block-sleep { background-color: rgba(30,58,138,0.3); border-left-color: #3B82F6; }
          .block-task { background-color: rgba(31,41,55,0.6); border-left-color: #9CA3AF; }
          .block-commitment { background-color: rgba(6,95,70,0.3); border-left-color: #10B981; }
          .block-time {
            font-size: 13px;
            color: var(--text-muted);
            margin-bottom: 4px;
          }
          .duration { font-size: 12px; opacity: 0.7; }
          .block-title {
            font-size: 16px;
            font-weight: 500;
          }
          .empty-state {
            text-align: center;
            padding: 40px 20px;
            color: var(--text-muted);
          }
          .footer {
            margin-top: 30px;
            text-align: center;
            font-size: 12px;
            color: var(--text-muted);
          }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <div class="badge-readonly">Read-Only View</div>
            <h1>Equilibrium Schedule</h1>
            <div class="meta-info">Generated for ${generatedAtStr}</div>
          </div>
          
          <div class="schedule-container">
            ${blocksHtml}
          </div>

          <div class="footer">
            <p>This shared schedule is private and will automatically expire on ${expiresAtStr}.</p>
            <p>Powered by Equilibrium</p>
          </div>
        </div>
      </body>
      </html>
    `;

    res.send(html);
  } catch (err) {
    next(err);
  }
});
