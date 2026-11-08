#!/bin/bash
# 1. Update package lists and install curl
apt-get update -y
apt-get install -y curl

# 2. Download and install the official AWS SSM Agent snap/deb package
# Since Floci containers route to the host, we fetch from the real AWS S3 repository
curl https://amazonaws.com -o /tmp/amazon-ssm-agent.deb
dpkg -i /tmp/amazon-ssm-agent.deb

# 3. Force the local agent to talk to Floci instead of real AWS endpoints
# We override the region's SSM endpoints by dropping a configuration override
mkdir -p /etc/amazon/ssm/
cat << 'EOF' > /etc/amazon/ssm/amazon-ssm-agent.json
{
    "Profile": {
        "ShareCreds": true,
        "ShareProfile": ""
    },
    "Mds": {
        "Endpoint": "http://169.254.169.254:4566",
        "Command": "ssm"
    },
    "Ssm": {
        "Endpoint": "http://169.254.169.254:4566",
        "Command": "ssm"
    }
}
EOF

# 4. Restart the SSM Agent daemon to apply changes
systemctl stop amazon-ssm-agent
systemctl start amazon-ssm-agent
