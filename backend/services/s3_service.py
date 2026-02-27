import boto3
import os
import uuid
from botocore.exceptions import ClientError
from datetime import datetime


class S3Service:
    def __init__(self):
        self.region = os.getenv("AWS_S3_REGION", "us-east-1")
        self.bucket = os.getenv("AWS_S3_BUCKET")

    def _client(self):
        """
        Create a fresh boto3 client on every call.
        AWS Academy session tokens expire every few hours —
        re-reading env vars each time ensures we always use the latest token.
        """
        token = os.getenv("AWS_SESSION_TOKEN", "NOT SET")
        print(f"🔑 AWS token preview: {token[:20]}...")
        print(f"🪣  Bucket: {self.bucket}")
        print(f"🌍 Region: {self.region}")

        return boto3.client(
            "s3",
            aws_access_key_id=os.getenv("AWS_ACCESS_KEY_ID"),
            aws_secret_access_key=os.getenv("AWS_SECRET_ACCESS_KEY"),
            aws_session_token=token if token != "NOT SET" else None,
            region_name=self.region,
        )

    def upload_file(self, file_content: bytes, filename: str) -> str:
        """Upload file to S3 and return public URL."""
        try:
            today = datetime.now().strftime("%Y/%m/%d")
            unique_id = uuid.uuid4().hex[:16]
            s3_key = f"voice_messages/{today}/{unique_id}_{filename}"

            print(f"📤 Uploading to S3: bucket={self.bucket}, key={s3_key}, size={len(file_content)} bytes")

            self._client().put_object(
                Bucket=self.bucket,
                Key=s3_key,
                Body=file_content,
                ContentType="audio/aac",
            )

            file_url = f"https://{self.bucket}.s3.{self.region}.amazonaws.com/{s3_key}"
            print(f"✅ S3 upload successful: {file_url}")
            return file_url

        except ClientError as e:
            print(f"❌ S3 ClientError: {e}")
            raise
        except Exception as e:
            print(f"❌ S3 unexpected error: {e}")
            raise


# Singleton — but client is created fresh on each upload call
s3_service = S3Service()