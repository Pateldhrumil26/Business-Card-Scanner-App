import mongoose, { Schema } from 'mongoose';
import { IBusinessCard } from '../types';

const businessCardSchema = new Schema<IBusinessCard>(
  {
    userId: {
      type: Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    originalImage: {
      type: String,
      required: [true, 'Image URL is required'],
    },
    backImage: {
      type: String,
      default: '',
    },
    s3Key: {
      type: String,
      default: '',
    },
    backS3Key: {
      type: String,
      default: '',
    },
    extractedText: {
      type: String,
      default: '',
    },
    processingStatus: {
      type: String,
      enum: ['pending', 'processing', 'completed', 'failed'],
      default: 'completed',
    },
  },
  {
    timestamps: true,
  }
);

const BusinessCard = mongoose.model<IBusinessCard>('BusinessCard', businessCardSchema);
export default BusinessCard;
