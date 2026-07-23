import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';

const s3 = new S3Client({ region: process.env.AWS_REGION ?? 'us-east-1' });

export async function uploadFile(key: string, body: Buffer, retries = 3) {
  for (let i = 0; i < retries; i++) {
    try {
      await s3.send(new PutObjectCommand({
        Bucket: process.env.S3_BUCKET,
        Key: key,
        Body: body,
      }));
      return;
    } catch (err) {
      if (i === retries - 1) throw err;
      await new Promise(r => setTimeout(r, 1000 * Math.pow(2, i)));
    }
  }
}
