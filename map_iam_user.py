import sys
import requests
import json
from requests.auth import HTTPBasicAuth
from urllib3.exceptions import InsecureRequestWarning

# Suppress only the single warning from urllib3 needed.
requests.packages.urllib3.disable_warnings(category=InsecureRequestWarning)

if len(sys.argv) != 6:
    print("Usage: python map_iam_user.py <endpoint> <username> <password> <iam_user_arn> <role_name>")
    sys.exit(1)

endpoint, username, password, iam_user_arn, role_name = sys.argv[1:6]

# Get current mapping
role_mapping_url = f"https://{endpoint}/_plugins/_security/api/rolesmapping/{role_name}"
auth = HTTPBasicAuth(username, password)
headers = {"Content-Type": "application/json"}

resp = requests.get(role_mapping_url, auth=auth, headers=headers, verify=False)
if resp.status_code not in [200, 404]:
    print(f"Failed to get current role mapping: {resp.status_code}\n{resp.text}")
    sys.exit(1)

if resp.status_code == 404:
    # Role mapping does not exist, create new
    mapping = {"backend_roles": [iam_user_arn]}
else:
    mapping = resp.json()
    backend_roles = set(mapping.get("backend_roles", []))
    backend_roles.add(iam_user_arn)
    mapping["backend_roles"] = list(backend_roles)

# Update mapping
resp = requests.put(role_mapping_url, auth=auth, headers=headers, data=json.dumps(mapping), verify=False)
print(f"Update role mapping response: {resp.status_code}")
print(resp.text)
if resp.status_code not in [200, 201]:
    sys.exit(1)
else:
    print(f"Successfully mapped {iam_user_arn} to role {role_name}") 