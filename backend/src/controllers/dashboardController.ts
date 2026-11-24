import { Response, NextFunction } from 'express';
import Contact from '../models/Contact';
import BusinessCard from '../models/BusinessCard';
import { AuthenticatedRequest } from '../types';

export const getStats = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<any> => {
  try {
    if (!req.user) {
      return res.status(401).json({ success: false, message: 'Not authenticated' });
    }

    const userId = req.user._id;

    const totalScannedCards = await BusinessCard.countDocuments({ userId });
    const totalContacts = await Contact.countDocuments({ userId });

    const uniqueCompanies = await Contact.distinct('companyName', {
      userId,
      companyName: { $exists: true, $ne: '' },
    });
    const totalCompanies = uniqueCompanies.length;

    const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
    const recentContactsCount = await Contact.countDocuments({
      userId,
      createdAt: { $gte: sevenDaysAgo },
    });

    res.status(200).json({
      success: true,
      stats: {
        totalScannedCards,
        totalContacts,
        totalCompanies,
        recentContactsCount,
      },
    });
  } catch (error) {
    next(error);
  }
};

export const getRecentContacts = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<any> => {
  try {
    if (!req.user) {
      return res.status(401).json({ success: false, message: 'Not authenticated' });
    }

    const userId = req.user._id;

    const recentContacts = await Contact.find({ userId })
      .populate('businessCardId', 'originalImage')
      .sort({ createdAt: -1 })
      .limit(5);

    const recentCards = await BusinessCard.find({ userId })
      .sort({ createdAt: -1 })
      .limit(5);

    res.status(200).json({
      success: true,
      recentContacts,
      recentCards,
    });
  } catch (error) {
    next(error);
  }
};
