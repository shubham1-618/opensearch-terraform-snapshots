import sys
import requests
import json
from requests.auth import HTTPBasicAuth
from urllib3.exceptions import InsecureRequestWarning

# Suppress only the single warning from urllib3 needed.
requests.packages.urllib3.disable_warnings(category=InsecureRequestWarning)

if len(sys.argv) != 5:
    print("Usage: python snapshot_policy.py <endpoint> <region> <username> <password>")
    sys.exit(1)

endpoint, region, username, password = sys.argv[1:5]
repo_name = "s3-repo"

# Use basic authentication
auth = HTTPBasicAuth(username, password)
headers = {"Content-Type": "application/json"}

# Step 1: Create index template for log indices with hot alias
index_template_url = f"https://{endpoint}/_index_template/snapshot_template"
index_template_payload = {
    "index_patterns": ["log*"],
    "template": {
        "settings": {
            "number_of_replicas": 1
        },
        "aliases": {
            "hot": {}
        }
    }
}

resp = requests.put(
    index_template_url,
    auth=auth,
    headers=headers,
    data=json.dumps(index_template_payload),
    verify=False
)

print(f"Create index template response: {resp.status_code}")
print(resp.text)

# Step 2: Create ISM policy for hot to warm migration with alias update
ism_policy_url = f"https://{endpoint}/_plugins/_ism/policies/alias_policy"
ism_policy_payload = {
    "policy": {
        "policy_id": "alias_policy",
        "description": "Policy for changing the alias and performing the warm migration",
        "default_state": "hot_alias",
        "states": [
            {
                "name": "hot_alias",
                "actions": [],
                "transitions": [
                    {
                        "state_name": "warm",
                        "conditions": {
                            "min_index_age": "30d"
                        }
                    }
                ]
            },
            {
                "name": "warm",
                "actions": [
                    {
                        "alias": {
                            "actions": [
                                {
                                    "remove": {
                                        "aliases": ["hot"]
                                    }
                                },
                                {
                                    "add": {
                                        "aliases": ["warm"]
                                    }
                                }
                            ]
                        }
                    },
                    {
                        "retry": {
                            "count": 5,
                            "backoff": "exponential",
                            "delay": "1h"
                        },
                        "warm_migration": {}
                    }
                ],
                "transitions": []
            }
        ],
        "ism_template": [
            {
                "index_patterns": ["log*"],
                "priority": 100
            }
        ]
    }
}

resp = requests.put(
    ism_policy_url,
    auth=auth,
    headers=headers,
    data=json.dumps(ism_policy_payload),
    verify=False
)

print(f"Create ISM policy response: {resp.status_code}")
print(resp.text)

# Step 3: Create snapshot management policy for hourly snapshots
snapshot_policy_url = f"https://{endpoint}/_plugins/_sm/policies/hourly-snapshot-policy"
snapshot_policy_payload = {
    "description": "Policy for Hourly Snapshots",
    "creation": {
        "schedule": {
            "cron": {
                "expression": "0 * * * *",  # Every hour
                "timezone": "UTC"
            }
        }
    },
    "deletion": {
        "schedule": {
            "cron": {
                "expression": "0 0 * * *",  # Daily at midnight
                "timezone": "UTC"
            }
        },
        "condition": {
            "min_count": 1,
            "max_count": 48  # Keep 2 days worth of hourly snapshots
        }
    },
    "snapshot_config": {
        "indices": "hot",  # Only backup hot indices
        "repository": repo_name
    }
}

resp = requests.post(
    snapshot_policy_url,
    auth=auth,
    headers=headers,
    data=json.dumps(snapshot_policy_payload),
    verify=False
)

print(f"Create snapshot management policy response: {resp.status_code}")
print(resp.text)

if resp.status_code in [200, 201]:
    print("Successfully created snapshot management policy")
else:
    print(f"Failed to create snapshot management policy: {resp.text}")
    sys.exit(1) 