import { S3Client } from '@aws-sdk/client-s3';
import dotenv from 'dotenv';

dotenv.config();

const region = process.env.AWS_REGION || 'ap-south-1';
const accessKeyId = process.env.AWS_ACCESS_KEY_ID;
const secretAccessKey = process.env.AWS_SECRET_ACCESS_KEY;

if (!accessKeyId || !secretAccessKey) {
  console.warn('[AWS S3] Warning: AWS_ACCESS_KEY_ID or AWS_SECRET_ACCESS_KEY is not defined in environment.');
}

export const s3Client = new S3Client({
  region,
  credentials: {
    accessKeyId: accessKeyId || '',
    secretAccessKey: secretAccessKey || '',
  },
});

export const S3_BUCKET_NAME = process.env.AWS_BUCKET_NAME || 'dhrumiiil';
export const S3_REGION = region;
