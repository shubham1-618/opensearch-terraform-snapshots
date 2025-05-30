import sys
import requests
import json
from requests.auth import HTTPBasicAuth
from urllib3.exceptions import InsecureRequestWarning

# Suppress only the single warning from urllib3 needed.
requests.packages.urllib3.disable_warnings(category=InsecureRequestWarning)

if len(sys.argv) != 5:
    print("Usage: python list_snapshots.py <endpoint> <repo_name> <username> <password>")
    sys.exit(1)

endpoint, repo_name, username, password = sys.argv[1:5]

# Use basic authentication
auth = HTTPBasicAuth(username, password)
headers = {"Content-Type": "application/json"}

# List snapshots in the repository
snapshots_url = f"https://{endpoint}/_snapshot/{repo_name}/_all"

resp = requests.get(
    snapshots_url,
    auth=auth,
    headers=headers,
    verify=False
)

if resp.status_code == 200:
    snapshots = json.loads(resp.text).get('snapshots', [])
    print(f"Available snapshots in repository '{repo_name}':")
    print("------------------------------------------------------------")
    print(f"{'SNAPSHOT NAME':<30} {'START TIME':<25} {'STATE':<15} {'INDICES'}")
    print("------------------------------------------------------------")
    
    for snapshot in snapshots:
        name = snapshot.get('snapshot', 'N/A')
        start_time = snapshot.get('start_time', 'N/A')
        state = snapshot.get('state', 'N/A')
        indices = ', '.join(snapshot.get('indices', []))
        
        print(f"{name:<30} {start_time:<25} {state:<15} {indices}")
else:
    print(f"Failed to list snapshots: {resp.status_code}")
    print(resp.text)
    sys.exit(1) 