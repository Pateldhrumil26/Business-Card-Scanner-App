import mongoose, { Schema } from 'mongoose';
import { IContact } from '../types';

const contactSchema = new Schema<IContact>(
  {
    userId: {
      type: Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    businessCardId: {
      type: Schema.Types.ObjectId,
      ref: 'BusinessCard',
      default: null,
    },
    personName: {
      type: String,
      required: [true, 'Person name is required'],
      trim: true,
      index: true,
    },
    companyName: {
      type: String,
      trim: true,
      default: '',
      index: true,
    },
    designation: {
      type: String,
      trim: true,
      default: '',
    },
    phone: {
      type: String,
      trim: true,
      default: '',
      index: true,
    },
    alternativePhone: {
      type: String,
      trim: true,
      default: '',
    },
    email: {
      type: String,
      trim: true,
      lowercase: true,
      default: '',
      index: true,
    },
    website: {
      type: String,
      trim: true,
      default: '',
    },
    address: {
      type: String,
      trim: true,
      default: '',
    },
    city: {
      type: String,
      trim: true,
      default: '',
    },
    state: {
      type: String,
      trim: true,
      default: '',
    },
    country: {
      type: String,
      trim: true,
      default: 'India',
    },
    gstNumber: {
      type: String,
      trim: true,
      default: '',
    },
    category: {
      type: String,
      trim: true,
      default: 'Business',
    },
    servicesOffered: {
      type: String,
      trim: true,
      default: '',
    },
    notes: {
      type: String,
      trim: true,
      default: '',
    },
  },
  {
    timestamps: true,
  }
);

// Compound index for user-scoped queries and fast search
contactSchema.index({ userId: 1, createdAt: -1 });
contactSchema.index({ userId: 1, companyName: 1 });
contactSchema.index({
  personName: 'text',
  companyName: 'text',
  phone: 'text',
  email: 'text',
  servicesOffered: 'text',
});

const Contact = mongoose.model<IContact>('Contact', contactSchema);
export default Contact;
