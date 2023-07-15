# Network Tools

## Terraform cloud

- Register: https://app.terraform.io
- Create API token at https://app.terraform.io/app/settings/tokens (User -> Setting -> Tokens)
- Create new Organization. Ex: `N-Chain`
- Create new Workspace with `CLI-driven workflow`. Ex: `testnet-nchaintools`

### Terraform local

- Copy `env.tf.dev` to `env.tf` and CORRECT `Org name` and `Workspace name` in `env.tf`
- IF you have multi credentials, you need to set TF_CLI_CONFIG_FILE each deployment:
    + Copy `.terraformrc.dev` to `.terraformrc` and CORRECT API token
    + Run this command: `export TF_CLI_CONFIG_FILE=".terraformrc"`
- ELSE just use global config by `terraform login` -> the config places at `$HOME/.terraform.d/credentials.tfrc.json`
- Initialize: `terraform init`

### Initial setup

- Create SSH keypair for bastion and project

```
# Keypair for bastion hosts
KEY_NAME=testnet-nchaintools-bastion && ssh-keygen -t rsa -f key_pairs/$KEY_NAME -C $KEY_NAME

# Keypair for project hosts
KEY_NAME=testnet-nchaintools-project && ssh-keygen -t rsa -f key_pairs/$KEY_NAME -C $KEY_NAME
```

- Login to AWS console:
    + IAM -> Create new `CLI` IAM User:
        + Name: `aws-tf-nchain`
        + Policies:
            + Built-in Attach policies directly: AmazonEC2FullAccess, AutoScalingFullAccess, AmazonVPCFullAccess,
              CloudWatchFullAccess, AmazonSNSFullAccess, AmazonRoute53FullAccess, AWSCertificateManagerFullAccess
            + Custom - Create policy: CreateEC2IAMRolePolicy

```
  {
      "Version": "2012-10-17",
      "Statement": [
          {
              "Effect": "Allow",
              "Action": [
                  "iam:AttachRolePolicy",
                  "iam:DeleteRolePolicy",
                  "iam:DetachRolePolicy",
                  "iam:GetRole",
                  "iam:GetRolePolicy",
                  "iam:ListAttachedRolePolicies",
                  "iam:ListRolePolicies",
                  "iam:PutRolePolicy",
                  "iam:UpdateRole",
                  "iam:UpdateRoleDescription",
                  "iam:CreateRole",
                  "iam:DeleteRole",
                  "iam:TagRole",
                  "iam:ListInstanceProfilesForRole",
                  "iam:GetInstanceProfile",
                  "iam:CreateInstanceProfile",
                  "iam:RemoveRoleFromInstanceProfile",
                  "iam:AddRoleToInstanceProfile",
                  "iam:PassRole",
                  "iam:DeleteInstanceProfile"
              ],
              "Resource": [
                  "arn:aws:iam::*:role/*-iam-role-*",
                  "arn:aws:iam::*:instance-profile/*-iam-profile-*"
              ]
          }
      ]
  }
```

+ AWS Secrets Manager -> New Secret -> Other type of secret
    + A secret as Plain text which used by bastion host:
        + Value: paste all content (include the end line) of `key_pairs/testnet-nchaintools-project` file
        + Name: `testnet-nchaintools-project`

- Prepare explorer config:
    + Update `network_config/ethernal_env` file:
        + ENCRYPTION_KEY should be a 32 characters hex
          string. https://codebeautify.org/generate-random-hexadecimal-numbers
        + ENCRYPTION_JWT_SECRET should be a 63 characters hex string
        + SECRET can be any random 64 characters hex string
        + VUE_APP_MAIN_DOMAIN: Your explorer domain
        + BULLBOARD_USERNAME and BULLBOARD_PASSWORD: The account accesses to `/bull` admin page
    + Update `network_config/ethernal_index.js` file:
        + Update to your value: EXPLORER_DOMAIN, EXPLORER_SLUG, RPC_SERVER, NETWORK_ID, NETWORK_TOKEN, SECRET

- Upload some config files in `network_config` folder to AWS Secrets Manager as Plaintext:
    - `ethernal_env` file to AWS with name `testnet-nchaintools-ethernal@env`
    - `ethernal_index.js` file to AWS with name `testnet-nchaintools-ethernal@index`

### Deploy

- Review and update local Terraform variables in `env.tf` file:
    + env=testnet
    + project=nchaintools
- Config Terraform variables on Terraform cloud:
    + AWS_ACCESS_KEY (sensitive) -> From `aws-tf-nchain` IAM user
    + AWS_SECRET_KEY (sensitive) -> From `aws-tf-nchain` IAM user
    + public_key_pair_bastion (sensitive) = content of `key_pairs/testnet-nchaintools-bastion.pub` file
    + public_key_pair_project (sensitive) = content of `key_pairs/testnet-nchaintools-project.pub` file
    + domain_zone_id = From AWS Console -> Route53 -> Selected domain -> Copy `Hosted zone ID`
    + domain_explore = `scan.nhancv.com`
    + ethernal_username = `me@nhancv.com`
    + ethernal_password (sensitive) = `secret`

- Deploy architecture to aws

```
terraform init
terraform plan
terraform apply [-auto-approve]

VIEW STATE
terraform show
-> Read instance input, public_ip
```

### Verify

- Verify scan: https://scan.nhancv.com

### Access to bastion host

```
chmod 600 key_pairs/testnet-nchaintools-bastion
ssh -i key_pairs/testnet-nchaintools-bastion ubuntu@<bastion_public_ip>

* Default username of Ubuntu instance is ubuntu. AWS Linux instance is ec2-user
```

### Access to private host

Only available in bastion host

```
ssh ubuntu@<project_private_ip>
```

### Shutdown

- Clean up all resources

```
terraform plan -destroy
terraform apply -destroy [-auto-approve]
```

- Delete AWS IAM user and AWS Secrets Manager secret
