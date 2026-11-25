import { Request } from 'express';
import { Document, Types } from 'mongoose';

export interface IUser extends Document {
  _id: Types.ObjectId;
  name: string;
  email: string;
  mobile?: string;
  password?: string;
  createdAt: Date;
  updatedAt: Date;
  matchPassword(enteredPassword: string): Promise<boolean>;
}

export interface IBusinessCard extends Document {
  _id: Types.ObjectId;
  userId: Types.ObjectId;
  originalImage: string; // S3 URL (Front)
  backImage?: string; // S3 URL (Back)
  s3Key?: string;
  backS3Key?: string;
  extractedText: string;
  processingStatus: 'pending' | 'processing' | 'completed' | 'failed';
  createdAt: Date;
  updatedAt: Date;
}

export interface IContact extends Document {
  _id: Types.ObjectId;
  userId: Types.ObjectId;
  businessCardId?: Types.ObjectId;
  cardImageUrl?: string;
  backImageUrl?: string;
  personName: string;
  companyName: string;
  designation: string;
  phone: string;
  alternativePhone: string;
  email: string;
  website: string;
  address: string;
  city: string;
  state: string;
  country: string;
  gstNumber: string;
  category: string;
  servicesOffered?: string;
  notes: string;
  createdAt: Date;
  updatedAt: Date;
}

export interface IDetectedPerson {
  name: string;
  designation?: string;
  phone?: string;
  email?: string;
}

export interface IParsedCardData {
  personName: string;
  companyName: string;
  designation: string;
  phone: string;
  alternativePhone: string;
  email: string;
  website: string;
  address: string;
  city: string;
  state: string;
  country: string;
  gstNumber: string;
  category: string;
  servicesOffered?: string;
  rawText: string;
  missingFields: string[];
  hasMultiplePersons?: boolean;
  detectedPersons?: IDetectedPerson[];
}

export interface ILineData {
  text: string;
  height?: number;
  width?: number;
  top?: number;
  left?: number;
}

export interface AuthenticatedRequest extends Request {
  user?: IUser;
}
