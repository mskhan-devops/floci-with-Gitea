
### Command to configure the floci clound endpoints on my host:

```bash
# Install AWS CLI
curl "https://amazonaws.com" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Set floci env variables
export AWS_ENDPOINT_URL=http://172.19.0.3:4566
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1

# floci UI:
http://0.0.0.0:4500/console/aws

# floci-aws emulator (list services in browser)
http://0.0.0.0:4566/




# list instance
aws ec2 describe-instances \
  --endpoint-url=http://localhost:4566 \
  --filters "Name=instance-state-name,Values=running" \
  --query "Reservations[*].Instances[*].[InstanceId, ImageId, State.Name]" \
  --output table


## Create instances:
aws ec2 run-instances \
  --image-id ami-0123456789abcdef0 \
  --instance-type t2.micro \
  --count 1


## Create instances with ssm agent installation
aws ec2 run-instances \
  --image-id ami-ubuntu-example \
  --instance-type t2.micro \
  --user-data file://install_ssm.sh


aws ec2 run-instances \
  --image-id ami-0123456789abcdef0 \
  --instance-type t2.micro \
  --user-data file://install_ssm.sh \
  --endpoint-url http://localhost:4566

# list ssm enabled instance
aws ssm describe-instance-information \
  --endpoint-url http://localhost:4566 \
  --query "InstanceInformationList[*].[InstanceId, PingStatus, AgentVersion, PlatformName]" \
  --output table

# Get a quick reference list of all running local EC2 targets
aws ec2 describe-instances \
  --endpoint-url http://localhost:4566 \
  --filters "Name=instance-state-name,Values=running" \
  --query "Reservations[*].Instances[*].[InstanceId, Tags[?Key=='Name'].Value | [0]]" \
  --output table


# list instance
aws ec2 describe-instances \
  --endpoint-url=http://localhost:4566 \
  --filters "Name=instance-state-name,Values=running" \
  --query "Reservations[*].Instances[*].[InstanceId, ImageId, State.Name]" \
  --output table


# Check SSM enabled instances:
aws ssm describe-instance-information \
  --endpoint-url=http://localhost:4566 \
  --query "InstanceInformationList[*].[InstanceId, PingStatus, AgentVersion]" \
  --output table


aws ssm start-session \
  --endpoint-url http://localhost:4566 \
  --target i-0123456789abcdef0


aws ssm describe-instance-information \
  --endpoint-url http://localhost:4566 \
  --query "InstanceInformationList[*].[InstanceId, PingStatus, AgentVersion, PlatformName]" \
  --output table