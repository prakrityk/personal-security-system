import boto3
import os
from dotenv import load_dotenv

load_dotenv()

try:
    s3 = boto3.client(
        "s3",
        aws_access_key_id=os.getenv("AWS_ACCESS_KEY_ID"),
        aws_secret_access_key=os.getenv("AWS_SECRET_ACCESS_KEY"),
        aws_session_token=os.getenv("AWS_SESSION_TOKEN"),  # ← ADD THIS!
        region_name=os.getenv("AWS_S3_REGION")
    )
    
    # List your buckets to test
    response = s3.list_buckets()
    print("✅ Connection successful!")
    print("Your buckets:")
    for bucket in response['Buckets']:
        print(f"  - {bucket['Name']}")
        
except Exception as e:
    print(f"❌ Connection failed: {e}")