import express, { Request, Response } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import dotenv from 'dotenv';
import connectDB from './config/db';
import errorHandler from './middlewares/errorHandler';

// Route files
import authRoutes from './routes/authRoutes';
import cardRoutes from './routes/cardRoutes';
import contactRoutes from './routes/contactRoutes';
import dashboardRoutes from './routes/dashboardRoutes';

dotenv.config();

const app = express();

// Connect to MongoDB
connectDB();

// Middlewares
app.use(
  helmet({
    crossOriginResourcePolicy: false,
  })
);
app.use(
  cors({
    origin: '*',
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'Accept'],
  })
);
app.use(express.json({ limit: '15mb' }));
app.use(express.urlencoded({ extended: true, limit: '15mb' }));

if (process.env.NODE_ENV !== 'production') {
  app.use(morgan('dev'));
}

// Health check endpoint
app.get('/api/health', (req: Request, res: Response) => {
  res.status(200).json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    service: 'Business Card Scanner & Contact Manager API (TypeScript)',
    storage: 'AWS S3',
    bucket: process.env.AWS_BUCKET_NAME || 'dhrumiiil',
    version: '1.0.0',
  });
});

// Mount Routes
app.use('/api/auth', authRoutes);
app.use('/api/cards', cardRoutes);
app.use('/api/contacts', contactRoutes);
app.use('/api/dashboard', dashboardRoutes);

// Catch 404
app.use((req: Request, res: Response) => {
  res.status(404).json({
    success: false,
    message: `API endpoint not found: ${req.method} ${req.originalUrl}`,
  });
});

// Centralized error handling
app.use(errorHandler);

const PORT = parseInt(process.env.PORT || '8080', 10);

let server: any;
if (process.env.NODE_ENV !== 'test') {
  server = app.listen(PORT, '0.0.0.0', () => {
    console.log(`\n=================================================`);
    console.log(`🚀 CardScanner TypeScript Backend running!`);
    console.log(`☁️ AWS S3 Bucket: ${process.env.AWS_BUCKET_NAME || 'dhrumiiil'}`);
    console.log(`📡 Local:   http://localhost:${PORT}`);
    console.log(`📡 LAN:     http://192.168.1.2:${PORT}`);
    console.log(`📱 Mobile:  http://10.0.2.2:${PORT} (Android Emulator)`);
    console.log(`🔒 Mode:    ${process.env.NODE_ENV || 'development'}`);
    console.log(`=================================================\n`);
  });

  server.on('error', (err: any) => {
    if (err.code === 'EADDRINUSE') {
      console.error(`\n⚠️ Port ${PORT} is in use! Retrying on fallback port 8000...`);
      server = app.listen(8000, '0.0.0.0', () => {
        console.log(`🚀 Backend running on fallback port: http://localhost:8000\n`);
      });
    } else {
      console.error('Server error:', err);
    }
  });

  // Secondary port listener on 5050 so apps configured with port 5050 connect seamlessly
  if (PORT !== 5050) {
    try {
      const secondaryServer = app.listen(5050, '0.0.0.0', () => {
        console.log(`📡 Secondary port 5050 active: http://localhost:5050/api`);
      });
      secondaryServer.on('error', (err: any) => {
        console.log(`Notice: Secondary port 5050 could not be bound (${err.code || err.message})`);
      });
    } catch {
      // ignore
    }
  }
}

export { app, server };
export default app;
