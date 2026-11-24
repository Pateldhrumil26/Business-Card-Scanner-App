import { Router } from 'express';
import { body } from 'express-validator';
import {
  createContact,
  getAllContacts,
  getContactById,
  updateContact,
  deleteContact,
  exportVcf,
} from '../controllers/contactController';
import { protect } from '../middlewares/authMiddleware';
import { validate } from '../middlewares/validationMiddleware';

const router = Router();

const contactValidation = [
  body('personName').trim().notEmpty().withMessage('Person name is required'),
  body('email').optional({ checkFalsy: true }).isEmail().withMessage('Invalid email format'),
  validate,
];

router.post('/', protect, contactValidation, createContact);
router.get('/', protect, getAllContacts);
router.get('/:id', protect, getContactById);
router.put('/:id', protect, updateContact);
router.delete('/:id', protect, deleteContact);
router.get('/:id/vcf', protect, exportVcf);

export default router;
