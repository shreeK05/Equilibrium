import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import { authRouter } from './routes/auth.routes';
import { tasksRouter } from './routes/tasks.routes';
import { schedulesRouter } from './routes/schedules.routes';
import { constraintsRouter } from './routes/constraints.routes';
import commitmentsRouter from './routes/commitments.routes';
import { insightsRouter } from './routes/insights.routes';
import { teamRouter } from './routes/team.routes';
import { importsRouter } from './routes/imports.routes';
import { notificationsRouter } from './routes/notifications.routes';
import { errorHandler } from './middleware/error';
import { requestCorrelation, requestLogger } from './middleware/logger';

export const app = express();

app.use(requestCorrelation);
app.use(requestLogger);

app.use(helmet());

const allowedOriginsString = process.env.ALLOWED_ORIGINS;
let corsOrigin: string | string[] = ['http://localhost:3000', 'http://localhost:8080'];
if (allowedOriginsString) {
  if (allowedOriginsString === '*' && process.env.NODE_ENV === 'production') {
    console.warn('ALLOWED_ORIGINS=* is permissive in production; configure explicit browser origins in Render.');
  }
  corsOrigin = allowedOriginsString === '*' ? '*' : allowedOriginsString.split(',');
}

app.use(cors({ origin: corsOrigin }));
app.use(express.json({ limit: '1mb' })); // Limit JSON payload size

app.get('/api/v1/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

app.use('/api/v1/auth', authRouter);
app.use('/api/v1/tasks', tasksRouter);
app.use('/api/v1/schedules', schedulesRouter);
app.use('/api/v1/constraints', constraintsRouter);
app.use('/api/v1/commitments', commitmentsRouter);
app.use('/api/v1/insights', insightsRouter);
app.use('/api/v1/team', teamRouter);
app.use('/api/v1/imports', importsRouter);
app.use('/api/v1/notifications', notificationsRouter);

app.use(errorHandler);
