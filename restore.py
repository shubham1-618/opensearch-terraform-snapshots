import sys
import requests
import json
from requests.auth import HTTPBasicAuth
from urllib3.exceptions import InsecureRequestWarning

# Suppress only the single warning from urllib3 needed.
requests.packages.urllib3.disable_warnings(category=InsecureRequestWarning)

if len(sys.argv) != 7:
    print("Usage: python restore.py <endpoint> <repo_name> <snapshot_name> <index_name> <username> <password>")
    sys.exit(1)

endpoint, repo_name, snapshot_name, index_name, username, password = sys.argv[1:7]

# Use basic authentication
auth = HTTPBasicAuth(username, password)
headers = {"Content-Type": "application/json"}

# Restore snapshot
restore_url = f"https://{endpoint}/_snapshot/{repo_name}/{snapshot_name}/_restore"
payload = {
    "indices": index_name,
    "include_global_state": False,
    "rename_pattern": "(.+)",
    "rename_replacement": "restored_$1"
}

print(f"Attempting to restore index '{index_name}' from snapshot '{snapshot_name}' in repository '{repo_name}'...")
print(f"The restored index will be named 'restored_{index_name}'")

resp = requests.post(
    restore_url,
    auth=auth,
    headers=headers,
    data=json.dumps(payload),
    verify=False
)

if resp.status_code in [200, 201]:
    print(f"Successfully initiated restore operation:")
    print(resp.text)
    
    # Check status of the restored index
    status_url = f"https://{endpoint}/_cat/indices/restored_{index_name}?format=json"
    
    print("\nWaiting for restore to complete...")
    import time
    time.sleep(5)  # Give it a few seconds to start
    
    status_resp = requests.get(
        status_url,
        auth=auth,
        headers=headers,
        verify=False
    )
    
    if status_resp.status_code == 200:
        try:
            index_status = json.loads(status_resp.text)
            if index_status:
                print(f"\nRestored index status:")
                for idx in index_status:
                    print(f"Index: {idx.get('index')}")
                    print(f"Status: {idx.get('health')}")
                    print(f"Docs Count: {idx.get('docs.count')}")
                    print(f"Size: {idx.get('store.size')}")
            else:
                print(f"\nThe restored index 'restored_{index_name}' is not yet available. Check again later.")
        except json.JSONDecodeError:
            print(f"\nError parsing index status response: {status_resp.text}")
    else:
        print(f"\nError checking restored index status: {status_resp.status_code}")
        print(status_resp.text)
else:
    print(f"Failed to restore snapshot: {resp.status_code}")
    print(resp.text)
    sys.exit(1) 