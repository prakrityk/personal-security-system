import boto3
import os
import uuid
from botocore.exceptions import ClientError
from datetime import datetime

class S3Service:
    def __init__(self):
        self.aws_access_key = os.getenv("AWS_ACCESS_KEY_ID")
        self.aws_secret_key = os.getenv("AWS_SECRET_ACCESS_KEY")
        self.aws_session_token = os.getenv("AWS_SESSION_TOKEN")  # Important for AWS Academy!
        self.region = os.getenv("AWS_S3_REGION", "us-east-1")
        self.bucket = os.getenv("AWS_S3_BUCKET")
        
        # Initialize S3 client with session token
        self.s3 = boto3.client(
            "s3",
            aws_access_key_id=self.aws_access_key,
            aws_secret_access_key=self.aws_secret_key,
            aws_session_token=self.aws_session_token,
            region_name=self.region
        )
    
    def upload_file(self, file_content: bytes, filename: str) -> str:
        """
        Upload file to S3 and return public URL
        """
        try:
            # Generate unique filename with date folder
            today = datetime.now().strftime("%Y/%m/%d")
            unique_id = uuid.uuid4().hex[:16]
            s3_key = f"voice_messages/{today}/{unique_id}_{filename}"
            
            # Upload to S3
            self.s3.put_object(
                Bucket=self.bucket,
                Key=s3_key,
                Body=file_content,
                ContentType="audio/aac",
               
            )
            
            # Generate URL
            file_url = f"https://{self.bucket}.s3.{self.region}.amazonaws.com/{s3_key}"
            print(f"✅ S3 upload successful: {file_url}")
            
            return file_url
            
        except ClientError as e:
            print(f"❌ S3 upload failed: {e}")
            raise
        except Exception as e:
            print(f"❌ Unexpected error: {e}")
            raise

# Create singleton instance
s3_service = S3Service()