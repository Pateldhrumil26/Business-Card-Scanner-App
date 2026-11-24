import { Router } from 'express';
import {
  uploadCard,
  getPresignedUrl,
  extractCardText,
  getAllCards,
  getCardById,
  deleteCard,
} from '../controllers/cardController';
import { protect } from '../middlewares/authMiddleware';
import { uploadLimiter } from '../middlewares/rateLimiter';

const router = Router();

// Upload card directly to AWS S3 (without Multer - accepts JSON { image: "base64..." })
router.post('/upload', protect, uploadLimiter, uploadCard);

// Pre-signed S3 URL generation
router.post('/presigned-url', protect, uploadLimiter, getPresignedUrl);

// Intelligent text extraction
router.post('/extract', protect, extractCardText);

// Business cards collection
router.get('/', protect, getAllCards);
router.get('/:id', protect, getCardById);
router.delete('/:id', protect, deleteCard);

export default router;
