import { PutObjectCommand, DeleteObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { s3Client, S3_BUCKET_NAME, S3_REGION } from '../config/s3';

export interface S3UploadResult {
  url: string;
  key: string;
  bucket: string;
}

export class S3Service {
  /**
   * Upload an image provided as Base64 string directly to AWS S3
   * (No Multer disk storage required)
   */
  static async uploadBase64(
    base64Data: string,
    mimeType: string = 'image/jpeg',
    originalName?: string
  ): Promise<S3UploadResult> {
    // Strip Data URI prefix if present (e.g. data:image/jpeg;base64,...)
    let cleanBase64 = base64Data;
    let detectedMime = mimeType;

    const match = base64Data.match(/^data:([a-zA-Z0-9]+\/[a-zA-Z0-9-.+]+);base64,(.+)$/);
    if (match) {
      detectedMime = match[1];
      cleanBase64 = match[2];
    }

    const buffer = Buffer.from(cleanBase64, 'base64');
    return await this.uploadBuffer(buffer, detectedMime, originalName);
  }

  /**
   * Upload a Buffer directly to AWS S3
   */
  static async uploadBuffer(
    buffer: Buffer,
    mimeType: string = 'image/jpeg',
    originalName?: string
  ): Promise<S3UploadResult> {
    // Validate file size (10MB max)
    const maxSize = parseInt(process.env.MAX_FILE_SIZE || '10485760', 10);
    if (buffer.length > maxSize) {
      throw new Error(`File size exceeds maximum allowed size of ${maxSize / (1024 * 1024)}MB.`);
    }

    // Determine extension
    let ext = '.jpg';
    if (mimeType.includes('png')) ext = '.png';
    else if (mimeType.includes('webp')) ext = '.webp';
    else if (originalName && originalName.includes('.')) {
      ext = '.' + originalName.split('.').pop()?.toLowerCase();
    }

    const timestamp = Date.now();
    const randomSuffix = Math.round(Math.random() * 1e9);
    const key = `cards/card-${timestamp}-${randomSuffix}${ext}`;

    const command = new PutObjectCommand({
      Bucket: S3_BUCKET_NAME,
      Key: key,
      Body: buffer,
      ContentType: mimeType,
    });

    await s3Client.send(command);

    const url = `https://${S3_BUCKET_NAME}.s3.${S3_REGION}.amazonaws.com/${key}`;

    return {
      url,
      key,
      bucket: S3_BUCKET_NAME,
    };
  }

  /**
   * Generate pre-signed PUT URL for client-direct S3 upload
   */
  static async getPresignedUploadUrl(
    fileName: string,
    mimeType: string = 'image/jpeg'
  ): Promise<{ presignedUrl: string; key: string; publicUrl: string }> {
    const ext = fileName.includes('.') ? '.' + fileName.split('.').pop()?.toLowerCase() : '.jpg';
    const key = `cards/card-${Date.now()}-${Math.round(Math.random() * 1e9)}${ext}`;

    const command = new PutObjectCommand({
      Bucket: S3_BUCKET_NAME,
      Key: key,
      ContentType: mimeType,
    });

    const presignedUrl = await getSignedUrl(s3Client, command, { expiresIn: 900 }); // 15 mins
    const publicUrl = `https://${S3_BUCKET_NAME}.s3.${S3_REGION}.amazonaws.com/${key}`;

    return { presignedUrl, key, publicUrl };
  }

  /**
   * Delete object from AWS S3
   */
  static async deleteFile(keyOrUrl: string): Promise<boolean> {
    try {
      if (!keyOrUrl) return false;

      let key = keyOrUrl;
      if (keyOrUrl.startsWith('http://') || keyOrUrl.startsWith('https://')) {
        const url = new URL(keyOrUrl);
        // Pathname starts with '/' e.g. /cards/card-123.jpg
        key = url.pathname.startsWith('/') ? url.pathname.slice(1) : url.pathname;
      }

      const command = new DeleteObjectCommand({
        Bucket: S3_BUCKET_NAME,
        Key: key,
      });

      await s3Client.send(command);
      return true;
    } catch (err: any) {
      console.error(`[S3Service] Failed to delete file ${keyOrUrl}:`, err.message);
      return false;
    }
  }
}
