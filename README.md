# aws-vpc-ec2-baseline

A reusable, security-conscious **CloudFormation** baseline that spins up a
single-region VPC with a public subnet, internet gateway, route table, a
hardened security group, and an Amazon Linux 2023 EC2 instance.

> Refactored and hardened from a training-lab script into a clean,
> parameterized, CI-scanned Infrastructure-as-Code module.

## Why this exists

The original lab used a bash script that:
- hard-coded `0.0.0.0/0` on port 22 (SSH open to the world),
- parsed AWS CLI JSON with fragile `grep | cut`,
- mixed regions (`--region us-east-1` while discovering the VPC elsewhere),
- and baked in Academy-specific names (`Cafe VPC`, `LabInstanceProfile`).

This repo fixes all of that and turns it into a **production-minded** artifact:
real IaC, real security defaults, and a CI pipeline that scans every change.

## Architecture

```
                 Internet
                     |
                     v
            +------------------+
            | Internet Gateway |
            +------------------+
                     |
           0.0.0.0/0 |  (egress route)
                     v
            +------------------+      +-------------------------+
            |  Public Subnet   |<----|  Route Table            |
            |  10.0.1.0/24     |      +-------------------------+
            +------------------+
                     |
        +------------+------------+
        |                         |
+------------------+     +------------------+
|  EC2 (AL2023)    |     |  Security Group  |
|  t3.micro        |     |  (no inbound by   |
|  SSM role        |     |   default)        |
+------------------+     +------------------+
        |
+--------------------------+
| IAM Instance Profile     |
| AmazonSSMManagedInstance |
| Core (Session Manager)   |
+--------------------------+
```

Default access path: **SSM Session Manager** over port 443 — no inbound
security-group rules, no exposed SSH key.

## Security decisions (and why)

| Decision | Why |
|----------|-----|
| **SSM-only by default** (no open port 22) | You can shell into the box via AWS Systems Manager Session Manager. Removes the #1 attack surface (open SSH) without losing admin access. |
| **Optional SSH scoped to a CIDR** (`AllowedSSHCidr`, default = VPC range) | If you must use SSH, it's never `0.0.0.0/0`. In real use you tighten it to your own IP. |
| **AMI from SSM parameter** (`AWS::SSM::Parameter::Value`) | No hard-coded AMI IDs that go stale. Always pulls the latest AL2023 at deploy time. |
| **Least-privilege IAM** | Instance gets only `AmazonSSMManagedInstanceCore` — nothing more. |
| **Parameterized CIDRs / instance type** | Reusable across dev/staging/prod without editing the template. |
| **CI security scan** (`checkov`) | Every PR is checked for misconfigurations before merge. |

## Deploy

```bash
# One-shot deploy (creates/updates the stack)
./deploy.sh dev

# Or directly:
aws cloudformation deploy \
  --template-file template.yaml \
  --stack-name dev-vpc-ec2-baseline \
  --parameter-overrides Environment=dev \
  --capabilities CAPABILITY_IAM \
  --no-fail-on-empty-changeset
```

Connect via SSM (no open port needed):

```bash
aws ssm start-session --target <InstanceId>
```

## Tear down

```bash
aws cloudformation delete-stack --stack-name dev-vpc-ec2-baseline
aws cloudformation wait stack-delete-complete --stack-name dev-vpc-ec2-baseline
```

## Cost

Within the AWS Free Tier: `t3.micro` + a single VPC costs ~$0 when stopped.
Always tear down when not in use to avoid stray charges.

## CI

`.github/workflows/ci.yml` runs on every push/PR:
- **cfn-lint** — CloudFormation syntax + best-practice rules.
- **checkov** — static security scan for IaC misconfigurations.

## License

MIT — see [LICENSE](LICENSE).
