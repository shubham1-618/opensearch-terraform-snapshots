import sys
import requests
import json
import boto3
import base64
from requests.auth import HTTPBasicAuth
from urllib3.exceptions import InsecureRequestWarning

# Suppress only the single warning from urllib3 needed.
requests.packages.urllib3.disable_warnings(category=InsecureRequestWarning)

if len(sys.argv) != 7:
    print("Usage: python snapshot_repository.py <endpoint> <bucket> <role_arn> <region> <username> <password>")
    sys.exit(1)

endpoint, bucket, role_arn, region, username, password = sys.argv[1:7]
repo_name = "s3-repo"

# Register snapshot repository
repo_url = f"https://{endpoint}/_snapshot/{repo_name}"
repo_payload = {
    "type": "s3",
    "settings": {
        "bucket": bucket,
        "region": region,
        "role_arn": role_arn
    }
}

# Use basic authentication
auth = HTTPBasicAuth(username, password)

resp = requests.put(
    repo_url, 
    auth=auth,
    headers={"Content-Type": "application/json"}, 
    data=json.dumps(repo_payload), 
    verify=False
)

print(f"Register repository response: {resp.status_code}")
print(resp.text)

if resp.status_code == 200:
    print(f"Successfully registered snapshot repository: {repo_name}")
else:
    print(f"Failed to register snapshot repository: {resp.text}")
    sys.exit(1) 