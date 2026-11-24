import { Router } from 'express';
import { getStats, getRecentContacts } from '../controllers/dashboardController';
import { protect } from '../middlewares/authMiddleware';

const router = Router();

router.get('/stats', protect, getStats);
router.get('/recent-contacts', protect, getRecentContacts);

export default router;
