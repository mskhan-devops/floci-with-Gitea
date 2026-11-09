# Floci + Gitea CI/CD sandbox

Local stand-ins for the GitHub/AWS services used by a typical container deploy
pipeline:

- **Floci** (`floci/floci`) emulates the AWS API on port `4566`.
- **Gitea** provides Git hosting and GitHub-Actions-compatible workflows.
- **act_runner** executes workflows in Docker job containers.

A complete demo lives in [`floci-cicd-demo/`](floci-cicd-demo/): Django + React,
Gitea OIDC, least-privilege IAM role, Floci ECR, SSM Run Command, and a Floci EC2
instance behind a static ALB and WAF.

## Stack

| Service | Container | Host access | Purpose |
| --- | --- | --- | --- |
| Floci API | `floci` | `http://127.0.0.1:4566` | AWS emulator |
| Floci UI | `floci-aws-ui` (optional) | `http://127.0.0.1:4500/console/aws` | Console |
| Gitea | `gitea` | `http://127.0.0.1:3000`, SSH `:2222` | Git + Actions |
| Runner | `gitea-runner` | internal only | Executes workflows |

All services share the `cicd-bridge` Docker network. The runner reaches Gitea at
`http://gitea:3000`; job containers reach Floci at `http://floci:4566`.

## Start the stack

```bash
docker compose up -d
curl http://127.0.0.1:3000/api/healthz
curl http://127.0.0.1:4566/
```

Gitea credentials used in this sandbox: `mskhan` / `mskhan@666`.

The Gitea image is pinned to `gitea/gitea:main-nightly`. Stable 1.28 does not
ship the Actions OIDC provider (`/api/actions/oidc`); the 1.29 dev build does.
This is the only reason for the nightly tag.

The optional `floci-aws-ui` console container is not part of this compose file.
If your Floci distribution provides it, start it on the same network and open
<http://127.0.0.1:4500/console/aws>.

## AWS CLI against Floci

```bash
export AWS_ENDPOINT_URL=http://127.0.0.1:4566
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1

aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].[InstanceId,State.Name,PrivateIpAddress]' \
  --output table

aws ssm describe-instance-information \
  --query 'InstanceInformationList[].[InstanceId,PingStatus,PlatformName]' \
  --output table
```

## Demo pipeline

Push any commit to the `main` branch of `mskhan/floci-cicd-demo`:

```bash
cd floci-cicd-demo
git push origin main
```

Gitea Actions then:

1. requests an OIDC ID token from Gitea,
2. assumes the `floci-cicd-demo-github-actions` IAM role,
3. builds the combined React/Django image,
4. pushes it to ECR as `<commit-sha>` and `latest`,
5. pulls and restarts the container on EC2 over SSM,
6. verifies `/healthz` and prints `DEPLOY_HEALTHY`.
7. On failure, opens or updates a Gitea issue.

The VPC, security groups, ALB, target group, listener, and WAF are provisioned
once and are not modified by the workflow.

See [`floci-cicd-demo/README.md`](floci-cicd-demo/README.md) for the full
architecture, IAM policies, EC2 bootstrap, ALB/WAF details, verification
commands, and Floci-specific limitations.

## Useful checks

```bash
# Workflow runs (Gitea API)
curl -s -u 'mskhan:mskhan@666' \
  http://127.0.0.1:3000/api/v1/repos/mskhan/floci-cicd-demo/actions/runs?limit=5

# ECR tags
aws ecr describe-images --repository-name floci-cicd-demo/app \
  --query 'imageDetails[].imageTags'

# ALB target health
aws elbv2 describe-target-health \
  --target-group-arn arn:aws:elasticloadbalancing:us-east-1:000000000000:targetgroup/floci-cicd-demo-tg/c1d42843db9e4082

# App through the ALB (host header selects the load balancer in Floci)
curl -H 'Host: floci-cicd-demo-alb-3532fd4ea9a64b7d.elb.localhost.floci.io' \
  http://172.19.0.3:8080/api/hello/

# App through the published EC2 port
curl http://127.0.0.1:30002/api/hello/
```

## Notes

- EC2 instances in Floci are nested containers. Their Docker daemon must use the
  `vfs` storage driver because overlayfs cannot create whiteout files there.
- Floci requires OIDC provider URLs to start with `https://`, even when Gitea is
  served over local HTTP.
- Floci accepts unsigned STS requests; the workflow uses `--no-sign-request`.
- ECR registry routing only works with `localhost:4566` and
  `<account>.dkr.ecr.<region>.localhost:4566` hosts.
- Emulated security groups, NACLs, and WAF rules are metadata; use host firewalls
  and Docker network isolation when testing enforcement.
- Floci exposes its own SSH proxy container for each emulated instance. That is
  not an AWS security-group rule; the demo instance's security group has no
  inbound port 22.
