import urllib.request
import ssl
import boto3
import urllib3

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

s3 = boto3.client(
    "s3",
    endpoint_url="https://minio-single:9000",
    aws_access_key_id="glynacadmin",
    aws_secret_access_key="glynacinternpass2026",
    verify=False,
    region_name="us-east-1"
)

bucket = "s3-core-test"
key = "boto3-sample.txt"
payload = b"Hello from boto3 SDK validation!"

# 1. Put Object with Metadata and Tags
s3.put_object(
    Bucket=bucket,
    Key=key,
    Body=payload,
    Metadata={"tested-by": "intern", "client": "boto3"},
    Tagging="env=dev&suite=validation"
)
print("[+] Object uploaded with custom metadata and tags.")

# 2. Verify Metadata & Tags via HeadObject / GetObjectTagging
head = s3.head_object(Bucket=bucket, Key=key)
tags = s3.get_object_tagging(Bucket=bucket, Key=key)
print("[+] Metadata:", head.get("Metadata"))
print("[+] Tags:", tags.get("TagSet"))

# 3. Generate Presigned URL & Verify Fetch
url = s3.generate_presigned_url(
    "get_object",
    Params={"Bucket": bucket, "Key": key},
    ExpiresIn=300
)
print("[+] Presigned URL generated:", url)

ctx = ssl._create_unverified_context()
req = urllib.request.Request(url)
with urllib.request.urlopen(req, context=ctx) as response:
    fetched = response.read()
    print("[+] Presigned Fetch Body:", fetched.decode())
    assert fetched == payload, "Fetched content does not match payload!"

print("[PASS] boto3 S3 API, Metadata, Tagging, and Presigned URLs verified.")
