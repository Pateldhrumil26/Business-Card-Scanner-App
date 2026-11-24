import { Response, NextFunction } from 'express';
import Contact from '../models/Contact';
import { VcfService } from '../services/vcfService';
import { AuthenticatedRequest } from '../types';

export const createContact = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<any> => {
  try {
    if (!req.user) {
      return res.status(401).json({ success: false, message: 'Not authenticated' });
    }

    const {
      businessCardId,
      personName,
      companyName,
      designation,
      phone,
      alternativePhone,
      email,
      website,
      address,
      city,
      state,
      country,
      gstNumber,
      category,
      servicesOffered,
      notes,
    } = req.body;

    if (!personName || personName.trim().length === 0) {
      return res.status(400).json({
        success: false,
        message: 'Person name is required.',
      });
    }

    const contact = await Contact.create({
      userId: req.user._id,
      businessCardId: businessCardId || null,
      personName: personName.trim(),
      companyName: (companyName || '').trim(),
      designation: (designation || '').trim(),
      phone: (phone || '').trim(),
      alternativePhone: (alternativePhone || '').trim(),
      email: (email || '').trim().toLowerCase(),
      website: (website || '').trim(),
      address: (address || '').trim(),
      city: (city || '').trim(),
      state: (state || '').trim(),
      country: (country || 'India').trim(),
      gstNumber: (gstNumber || '').trim(),
      category: (category || 'Business').trim(),
      servicesOffered: (servicesOffered || '').trim(),
      notes: (notes || '').trim(),
    });

    res.status(201).json({
      success: true,
      message: 'Contact saved successfully',
      contact,
    });
  } catch (error) {
    next(error);
  }
};

export const getAllContacts = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<any> => {
  try {
    if (!req.user) {
      return res.status(401).json({ success: false, message: 'Not authenticated' });
    }

    const {
      search,
      company,
      sortBy = 'newest',
      page = '1',
      limit = '20',
    } = req.query;

    const pageNum = Math.max(1, parseInt(page as string, 10));
    const limitNum = Math.max(1, parseInt(limit as string, 10));
    const skip = (pageNum - 1) * limitNum;

    const query: any = { userId: req.user._id };

    if (search && (search as string).trim()) {
      const regex = new RegExp((search as string).trim(), 'i');
      query.$or = [
        { personName: regex },
        { companyName: regex },
        { phone: regex },
        { email: regex },
      ];
    }

    if (company && (company as string).trim()) {
      query.companyName = new RegExp(`^${(company as string).trim()}$`, 'i');
    }

    let sortOptions: any = { createdAt: -1 };
    if (sortBy === 'oldest') {
      sortOptions = { createdAt: 1 };
    } else if (sortBy === 'name-asc') {
      sortOptions = { personName: 1 };
    } else if (sortBy === 'name-desc') {
      sortOptions = { personName: -1 };
    } else if (sortBy === 'company-asc') {
      sortOptions = { companyName: 1 };
    }

    const total = await Contact.countDocuments(query);
    const contacts = await Contact.find(query)
      .populate('businessCardId', 'originalImage')
      .sort(sortOptions)
      .skip(skip)
      .limit(limitNum);

    const companies = await Contact.distinct('companyName', {
      userId: req.user._id,
      companyName: { $ne: '' },
    });

    res.status(200).json({
      success: true,
      total,
      page: pageNum,
      pages: Math.ceil(total / limitNum),
      contacts,
      companies,
    });
  } catch (error) {
    next(error);
  }
};

export const getContactById = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<any> => {
  try {
    if (!req.user) {
      return res.status(401).json({ success: false, message: 'Not authenticated' });
    }

    const contact = await Contact.findOne({
      _id: req.params.id,
      userId: req.user._id,
    }).populate('businessCardId', 'originalImage extractedText');

    if (!contact) {
      return res.status(404).json({
        success: false,
        message: 'Contact not found',
      });
    }

    res.status(200).json({
      success: true,
      contact,
    });
  } catch (error) {
    next(error);
  }
};

export const updateContact = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<any> => {
  try {
    if (!req.user) {
      return res.status(401).json({ success: false, message: 'Not authenticated' });
    }

    const contact = await Contact.findOne({
      _id: req.params.id,
      userId: req.user._id,
    });

    if (!contact) {
      return res.status(404).json({
        success: false,
        message: 'Contact not found',
      });
    }

    const updatableFields = [
      'personName',
      'companyName',
      'designation',
      'phone',
      'alternativePhone',
      'email',
      'website',
      'address',
      'city',
      'state',
      'country',
      'gstNumber',
      'category',
      'servicesOffered',
      'notes',
    ];

    for (const field of updatableFields) {
      if (req.body[field] !== undefined) {
        (contact as any)[field] =
          typeof req.body[field] === 'string' ? req.body[field].trim() : req.body[field];
      }
    }

    await contact.save();

    res.status(200).json({
      success: true,
      message: 'Contact updated successfully',
      contact,
    });
  } catch (error) {
    next(error);
  }
};

export const deleteContact = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<any> => {
  try {
    if (!req.user) {
      return res.status(401).json({ success: false, message: 'Not authenticated' });
    }

    const contact = await Contact.findOne({
      _id: req.params.id,
      userId: req.user._id,
    });

    if (!contact) {
      return res.status(404).json({
        success: false,
        message: 'Contact not found',
      });
    }

    await contact.deleteOne();

    res.status(200).json({
      success: true,
      message: 'Contact deleted successfully',
    });
  } catch (error) {
    next(error);
  }
};

export const exportVcf = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<any> => {
  try {
    if (!req.user) {
      return res.status(401).json({ success: false, message: 'Not authenticated' });
    }

    const contact = await Contact.findOne({
      _id: req.params.id,
      userId: req.user._id,
    });

    if (!contact) {
      return res.status(404).json({
        success: false,
        message: 'Contact not found',
      });
    }

    const vcfContent = VcfService.generateVCard(contact);
    const filename = `${(contact.personName || 'contact').replace(/[^a-zA-Z0-9]/g, '_')}.vcf`;

    res.setHeader('Content-Type', 'text/vcard; charset=utf-8');
    res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
    res.status(200).send(vcfContent);
  } catch (error) {
    next(error);
  }
};
