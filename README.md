# multi-stack-cloudformation-tf-iac-module

## AWS VPC + Private EC2 + S3 with CloudFormation & Terraform

Production-ready IaC that deploys **two identical VPC environments** using CloudFormation templates orchestrated with Terraform. Each stack creates a VPC with public/private subnets, private EC2 instance (Ubuntu 22.04), S3 bucket with VPC endpoint access, and automatic AMI resolution.

## 📋 What It Creates

**Two separate, identical stacks:**

Primary Stack:
- **VPC** (10.0.0.0/16) with public & private subnets
- **EC2 Instance** (Ubuntu 22.04, t2.small) in private subnet  
- **S3 Bucket** with VPC endpoint access (no internet traversal)
- **IAM Role** with scoped S3 read/write permissions
- **S3 VPC Endpoint** (Gateway type) + security groups

Secondary Stack (identical):
- Same resources as primary (in same region/account)
- Different stack name (`{stack_name}-secondary`)
- Separate EC2, VPC, S3, and IAM resources

**Cost:** ~$10-20/month (2 x t2.small + 2 x S3 storage)

## 📁 Project Structure

```
iac-with-cloudformation/
├── main.tf                      # Root module (orchestrates deployment)
├── variables.tf                 # Input variables
├── outputs.tf                   # Stack outputs
├── cloudformation_module/       # Reusable CF module
│   ├── main.tf                  # AMI lookup + CF stack
│   ├── variables.tf
│   └── outputs.tf
├── templates/
│   └── vpc-cf-template.yaml     # CloudFormation template
├── creds.sh                     # AWS credentials helper
└── README.md                    # This file
```

## 🚀 Quick Start

### 1. Set AWS Credentials (choose one)

**Option A: Environment variables**
```bash
export AWS_ACCESS_KEY_ID="your-key"
export AWS_SECRET_ACCESS_KEY="your-secret"
export AWS_DEFAULT_REGION="us-east-1"
```

**Option B: AWS CLI**
```bash
aws configure
```

**Option C: Helper script**
```bash
source creds.sh
```

**Option D: AWS SSO (production)**
```bash
aws sso login --profile your-profile
export AWS_PROFILE=your-profile
```

### 2. Deploy

```bash
cd /path/to/iac-with-cloudformation
terraform init
terraform apply -auto-approve -var='region=us-east-1'
```

This creates **two identical stacks**:
- Primary: `lab-vpc-stack`
- Secondary: `lab-vpc-stack-secondary`

Takes ~5-10 minutes (both stacks in parallel). View outputs:
```bash
terraform output
```

### 3. Destroy

```bash
terraform destroy -auto-approve -var='region=us-east-1'
```

## 📝 Terraform Commands

| Command | Purpose |
|---------|---------|
| `terraform init` | Initialize working directory |
| `terraform validate` | Validate syntax |
| `terraform plan -var='region=us-east-1'` | Show deployment plan |
| `terraform apply -auto-approve -var='region=us-east-1'` | Deploy stack |
| `terraform output` | View outputs |
| `terraform destroy -auto-approve -var='region=us-east-1'` | Delete all resources |

## 🔧 Configuration

### Input Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `region` | `us-east-1` | AWS region |
| `stack_name` | `lab-vpc-stack` | CloudFormation stack name |
| `ubuntu_ami` | `""` (auto-lookup) | Explicit Ubuntu AMI ID (optional) |
| `cf_parameters` | `{}` | Additional CF parameters |

### Examples

**Deploy both stacks to us-east-1:**
```bash
terraform apply -auto-approve -var='region=us-east-1'
```

**Deploy both stacks to different region:**
```bash
terraform apply -auto-approve -var='region=us-west-2'
```

**Deploy with custom primary stack name (secondary becomes `{name}-secondary`):**
```bash
terraform apply -auto-approve -var='stack_name=my-vpc-stack'
```

**Use specific AMI:**
```bash
terraform apply -auto-approve -var='ubuntu_ami=ami-0c55b159cbfafe1f0'
```

**Deploy only primary stack (comment out secondary module):**
Edit `main.tf` and comment out the `cloudformation_stack_secondary` module, then:
```bash
terraform apply -auto-approve -var='region=us-east-1'
```

**Create terraform.tfvars for defaults:**
```hcl
region      = "ap-south-1"
stack_name  = "my-vpc-stack"
ubuntu_ami  = ""
```

Then just run: `terraform apply -auto-approve`

## 📤 Outputs

After deployment, you get outputs for **both stacks**:

```bash
# Primary stack
terraform output primary_stack_id
terraform output primary_stack_outputs
terraform output primary_stack_outputs.RobotInstanceId

# Secondary stack
terraform output secondary_stack_id
terraform output secondary_stack_outputs
terraform output secondary_stack_outputs.RobotInstanceId
```

View all outputs:
```bash
terraform output -json
```

## 🔒 Security

✅ **Current:** EC2 in private subnet, S3 bucket access restricted to role, VPC endpoint (no internet)  
⚠️ **Note:** SSH allows 0.0.0.0/0 but unreachable (private instance)

### Recommendations
- Restrict SSH to specific IPs via bastion host
- Use AWS Systems Manager Session Manager instead of SSH
- Enable VPC Flow Logs for monitoring
- Use least-privilege IAM credentials
- Add cost center tags via `cf_parameters`

## 🔄 How AMI Lookup Works

Terraform automatically finds the latest Ubuntu 22.04 (Jammy) AMI:

```terraform
# In cloudformation_module/main.tf
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]  # Canonical
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}
```

**Benefits:**
- ✅ No hard-coded AMI IDs (avoids expiration)
- ✅ Avoids CloudFormation SSM parameter issues
- ✅ Region-aware and always current
- ✅ Can override with `-var='ubuntu_ami=ami-...'`

## 🐛 Troubleshooting

### "Unable to get credentials"
```bash
aws sts get-caller-identity  # Verify credentials
```

### "Insufficient IAM permissions"
Check that your user has CloudFormation, EC2, VPC, S3, IAM permissions.

### "No AMI found"
```bash
aws ec2 describe-images --owners 099720109477 \
  --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04*" \
  --region us-east-1
```

Then use explicit AMI: `-var='ubuntu_ami=ami-xxxxx'`

### "Stack deletion hangs (DELETE_IN_PROGRESS)"
This is now fixed. S3 bucket policy no longer references VPC endpoint. Try again:
```bash
terraform destroy -auto-approve -var='region=us-east-1'
```

### "State locked"
```bash
terraform force-unlock <LOCK_ID>
```

## 📊 Architecture

```
┌─────────────────── AWS Account ──────────────────┐
│                                                   │
│  ┌──────────────── VPC (10.0.0.0/16) ──────┐   │
│  │                                          │   │
│  │  Public Subnet (10.0.0.0/24)            │   │
│  │  └─ Internet Gateway                    │   │
│  │                                          │   │
│  │  Private Subnet (10.0.1.0/24)           │   │
│  │  ├─ EC2 (Ubuntu 22.04)                  │   │
│  │  │  ├─ IAM Role (S3 access)            │   │
│  │  │  └─ Security Group                   │   │
│  │  └─ S3 VPC Endpoint (Gateway)           │   │
│  │                                          │   │
│  └──────────────────────────────────────────┘   │
│                                                   │
│  S3 Bucket (restricted to EC2 role)             │
│                                                   │
└───────────────────────────────────────────────────┘
```

## 🎓 Module Design

Three-layer modular structure:

1. **Root Module** (`main.tf`, `variables.tf`, `outputs.tf`)
   - AWS provider config
   - Calls `cloudformation_module`
   - Passes variables through

2. **CloudFormation Module** (`cloudformation_module/`)
   - Ubuntu AMI lookup
   - Creates CloudFormation stack
   - Outputs CF results

3. **CloudFormation Template** (`templates/vpc-cf-template.yaml`)
   - Declarative AWS resources (VPC, EC2, S3, IAM)
   - Parameters for dynamic values
   - Resource outputs

**Benefits:** Reusable module, clear separation, easy customization

## 🛠️ Advanced Usage

### Remote State (Production)

```hcl
# Add to main.tf
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "iac-with-cloudformation/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}
```

### Multi-Environment

```bash
terraform apply -var-file=prod.tfvars
terraform apply -var-file=dev.tfvars
```

### CI/CD (GitHub Actions)

```yaml
name: Deploy
on: [push]
jobs:
  terraform:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: hashicorp/setup-terraform@v1
      - run: terraform init && terraform validate && terraform plan
      - run: terraform apply -auto-approve
```

## 📚 Key Features

✅ **Dual-stack deployment** (two identical environments with single command)  
✅ Automatic Ubuntu AMI lookup (no hard-coded IDs)  
✅ Fixed CloudFormation deletion (no DELETE_IN_PROGRESS hangs)  
✅ Modular, reusable design  
✅ 4 credential setup methods  
✅ Production-ready with security best practices  
✅ Multi-region support  
✅ Clear separation of concerns  

## 🔗 References

- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [CloudFormation User Guide](https://docs.aws.amazon.com/cloudformation/)
- [VPC Endpoints](https://docs.aws.amazon.com/vpc/latest/privatelink/)

## 🤝 Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on how to contribute to this project.

## 📄 License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for the full text. When reusing this software, please ensure that the original copyright notice and attribution to **Vijay Mourya** are included.

---

**Quick Deployment Summary:**
1. `export AWS_ACCESS_KEY_ID=...` (set credentials)
2. `terraform init`
3. `terraform apply -auto-approve -var='region=us-east-1'`
4. `terraform output` (view results)
5. `terraform destroy -auto-approve -var='region=us-east-1'` (cleanup)

**Questions?** Check the CloudFormation template at `templates/vpc-cf-template.yaml` or terraform configs in `cloudformation_module/`.
