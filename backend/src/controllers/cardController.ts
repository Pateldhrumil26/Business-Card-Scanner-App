import { Response, NextFunction } from 'express';
import BusinessCard from '../models/BusinessCard';
import { CardParserService } from '../services/cardParserService';
import { S3Service } from '../services/s3Service';
import { AuthenticatedRequest } from '../types';

/**
 * @route   POST /api/cards/upload
 * @desc    Upload business card image directly to AWS S3 (without Multer)
 * @access  Private
 * @body    { image: "base64String...", mimeType?: "image/jpeg", fileName?: "card.jpg" }
 */
export const uploadCard = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<any> => {
  try {
    if (!req.user) {
      return res.status(401).json({ success: false, message: 'Not authenticated' });
    }

    const { image, imageBase64, backImage, backImageBase64, mimeType = 'image/jpeg', fileName } = req.body;
    const base64Data = image || imageBase64;
    const backData = backImage || backImageBase64;

    if (!base64Data || typeof base64Data !== 'string') {
      return res.status(400).json({
        success: false,
        message: 'Please provide image data as a Base64 string in { "image": "..." }',
      });
    }

    // Direct AWS S3 Upload for Front Side using S3 PutObjectCommand
    const s3Result = await S3Service.uploadBase64(base64Data, mimeType, fileName);

    // Optional Upload for Back Side if 2-sided card scanned
    let backS3Result: { key: string; url: string } | null = null;
    if (backData && typeof backData === 'string') {
      const backFileName = fileName ? `back_${fileName}` : 'back_card.jpg';
      backS3Result = await S3Service.uploadBase64(backData, mimeType, backFileName);
    }

    const businessCard = await BusinessCard.create({
      userId: req.user._id,
      originalImage: s3Result.url,
      backImage: backS3Result ? backS3Result.url : '',
      s3Key: s3Result.key,
      backS3Key: backS3Result ? backS3Result.key : '',
      processingStatus: 'pending',
    });

    res.status(201).json({
      success: true,
      message: 'Card image(s) uploaded successfully to AWS S3',
      card: {
        id: businessCard._id,
        imageUrl: s3Result.url,
        backImageUrl: backS3Result ? backS3Result.url : '',
        s3Key: s3Result.key,
        processingStatus: businessCard.processingStatus,
        createdAt: businessCard.createdAt,
      },
    });
  } catch (error: any) {
    next(error);
  }
};

/**
 * @route   POST /api/cards/presigned-url
 * @desc    Generate pre-signed S3 URL for client-direct upload
 * @access  Private
 */
export const getPresignedUrl = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<any> => {
  try {
    const { fileName = 'card.jpg', mimeType = 'image/jpeg' } = req.body;
    const data = await S3Service.getPresignedUploadUrl(fileName, mimeType);

    res.status(200).json({
      success: true,
      ...data,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @route   POST /api/cards/extract
 * @desc    Extract structured contact details from OCR text
 * @access  Private
 */
export const extractCardText = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<any> => {
  try {
    if (!req.user) {
      return res.status(401).json({ success: false, message: 'Not authenticated' });
    }

    const { rawText, cardId, lineData } = req.body;

    if (!rawText || typeof rawText !== 'string' || rawText.trim().length === 0) {
      return res.status(400).json({
        success: false,
        message: 'No text was provided for extraction. Please provide raw OCR text.',
      });
    }

    // Intelligently parse the OCR text with visual line size hints
    const extractedData = CardParserService.parseBusinessCardText(rawText, lineData);

    console.log('\n=================================================');
    console.log('📸 SCANNED CARD OCR TEXT RECEIVED:');
    console.log('-------------------------------------------------');
    console.log(rawText.trim());
    console.log('-------------------------------------------------');
    console.log('📊 PARSED CONTACT DETAILS:');
    console.log('Person Name:  ', extractedData.personName);
    console.log('Company Name: ', extractedData.companyName);
    console.log('Designation:  ', extractedData.designation);
    console.log('Mobile Phone: ', extractedData.phone);
    console.log('Alt Phone:    ', extractedData.alternativePhone);
    console.log('Email:        ', extractedData.email);
    console.log('Website:      ', extractedData.website);
    console.log('Address:      ', extractedData.address);
    console.log('GST Number:   ', extractedData.gstNumber);
    console.log('Services:     ', extractedData.servicesOffered || 'None');
    console.log('=================================================\n');

    // If a cardId was associated, update its record
    if (cardId) {
      await BusinessCard.findOneAndUpdate(
        { _id: cardId, userId: req.user._id },
        {
          extractedText: rawText,
          processingStatus: 'completed',
        }
      );
    }

    res.status(200).json({
      success: true,
      message: 'Text successfully extracted and structured',
      data: extractedData,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @route   GET /api/cards
 * @desc    Get all scanned cards for authenticated user
 * @access  Private
 */
export const getAllCards = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<any> => {
  try {
    if (!req.user) {
      return res.status(401).json({ success: false, message: 'Not authenticated' });
    }

    const page = parseInt(req.query.page as string, 10) || 1;
    const limit = parseInt(req.query.limit as string, 10) || 20;
    const skip = (page - 1) * limit;

    const total = await BusinessCard.countDocuments({ userId: req.user._id });
    const cards = await BusinessCard.find({ userId: req.user._id })
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit);

    res.status(200).json({
      success: true,
      total,
      page,
      pages: Math.ceil(total / limit),
      cards,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @route   GET /api/cards/:id
 * @desc    Get single scanned card by ID
 * @access  Private
 */
export const getCardById = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<any> => {
  try {
    if (!req.user) {
      return res.status(401).json({ success: false, message: 'Not authenticated' });
    }

    const card = await BusinessCard.findOne({
      _id: req.params.id,
      userId: req.user._id,
    });

    if (!card) {
      return res.status(404).json({
        success: false,
        message: 'Business card not found',
      });
    }

    res.status(200).json({
      success: true,
      card,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @route   DELETE /api/cards/:id
 * @desc    Delete scanned card & remove its image from AWS S3
 * @access  Private
 */
export const deleteCard = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<any> => {
  try {
    if (!req.user) {
      return res.status(401).json({ success: false, message: 'Not authenticated' });
    }

    const card = await BusinessCard.findOne({
      _id: req.params.id,
      userId: req.user._id,
    });

    if (!card) {
      return res.status(404).json({
        success: false,
        message: 'Business card not found',
      });
    }

    // Delete object from AWS S3
    if (card.s3Key || card.originalImage) {
      await S3Service.deleteFile(card.s3Key || card.originalImage);
    }

    await card.deleteOne();

    res.status(200).json({
      success: true,
      message: 'Business card deleted successfully from database and AWS S3',
    });
  } catch (error) {
    next(error);
  }
};
