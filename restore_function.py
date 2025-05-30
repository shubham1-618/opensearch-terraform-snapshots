import os
import json
import boto3
import requests
from requests_aws4auth import AWS4Auth

def lambda_handler(event, context):
    host = os.environ['OPENSEARCH_ENDPOINT']
    region = os.environ['REGION']
    repo_name = 's3-repo'
    service = 'es'
    credentials = boto3.Session().get_credentials()
    awsauth = AWS4Auth(credentials.access_key, credentials.secret_key, region, service, session_token=credentials.token)

    snapshot_name = event.get('snapshot_name')
    index_name = event.get('index_name')
    if not snapshot_name or not index_name:
        return {"statusCode": 400, "body": "snapshot_name and index_name are required"}

    restore_url = f"https://{host}/_snapshot/{repo_name}/{snapshot_name}/_restore"
    payload = {"indices": index_name, "rename_pattern": ".*", "rename_replacement": f"restored_{index_name}"}
    headers = {"Content-Type": "application/json"}
    r = requests.post(restore_url, auth=awsauth, json=payload, headers=headers)
    print(f"Restore index: {r.status_code} {r.text}")
    return {"statusCode": r.status_code, "body": r.text} 