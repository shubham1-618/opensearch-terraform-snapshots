import os
import json
import boto3
import requests
from requests_aws4auth import AWS4Auth
from datetime import datetime

def lambda_handler(event, context):
    host = os.environ['OPENSEARCH_ENDPOINT']
    region = os.environ['REGION']
    s3_bucket = os.environ['S3_BUCKET']
    repo_name = 's3-repo'
    role_arn = os.environ['SNAPSHOT_ROLE_ARN']
    service = 'es'
    credentials = boto3.Session().get_credentials()
    awsauth = AWS4Auth(credentials.access_key, credentials.secret_key, region, service, session_token=credentials.token)

    # Register snapshot repository
    repo_url = f"https://{host}/_snapshot/{repo_name}"
    repo_payload = {
        "type": "s3",
        "settings": {
            "bucket": s3_bucket,
            "region": region,
            "role_arn": role_arn
        }
    }
    headers = {"Content-Type": "application/json"}
    r = requests.put(repo_url, auth=awsauth, json=repo_payload, headers=headers)
    print(f"Register repo: {r.status_code} {r.text}")

    # Trigger snapshot
    datestamp = datetime.utcnow().strftime('%Y%m%d%H%M%S')
    snapshot_name = f"snapshot-{datestamp}"
    snap_url = f"https://{host}/_snapshot/{repo_name}/{snapshot_name}"
    snap_payload = {"indices": "*"}
    r = requests.put(snap_url, auth=awsauth, json=snap_payload, headers=headers)
    print(f"Trigger snapshot: {r.status_code} {r.text}")
    return {"statusCode": r.status_code, "body": r.text} 