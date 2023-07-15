# Network Core

## Terraform cloud

- Register: https://app.terraform.io
- Create API token at https://app.terraform.io/app/settings/tokens (User -> Setting -> Tokens)
- Create new Organization. Ex: `N-Chain`
- Create new Workspace with `CLI-driven workflow`. Ex: `testnet-nchaincore`

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
KEY_NAME=testnet-nchaincore-bastion && ssh-keygen -t rsa -f key_pairs/$KEY_NAME -C $KEY_NAME

# Keypair for project hosts
KEY_NAME=testnet-nchaincore-project && ssh-keygen -t rsa -f key_pairs/$KEY_NAME -C $KEY_NAME
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
        + Value: paste all content (include the end line) of `key_pairs/testnet-nchaincore-project` file
        + Name: `testnet-nchaincore-project`

### Create network config on your local

- Install besu cli to your device
  first: https://besu.hyperledger.org/stable/public-networks/get-started/install/binary-distribution

```
# On MAC
brew tap hyperledger/besu
brew install hyperledger/besu/besu

# On Linux
BESU_VERSION=23.4.1 && \
BESU_DIR=besu-${BESU_VERSION} && \
wget https://hyperledger.jfrog.io/hyperledger/besu-binaries/besu/${BESU_VERSION}/besu-${BESU_VERSION}.tar.gz && \
sudo tar xvzf ${BESU_DIR}.tar.gz && \
cd ${BESU_DIR} && sudo ln -s $(pwd)/bin/besu /usr/bin/besu

# Verify
besu --version
```

- Generate genesis file on local, keep all files safe:

```
# At directory contain ibftconf.json file
besu operator generate-blockchain-config --config-file=ibftconf.json --to=networkFiles --private-key-file-name=key

Ouput:
networkFiles/
├── genesis.json
└── keys
    ├── wallet-node-1
    │   ├── key
    │   └── key.pub
    ├── wallet-node-2
    ├── wallet-node-3
    ├── wallet-node-4
```

- Prepare network config file:
    + Update `network_config/ibftconf.json` file:
        + Update `CHAIN_ID`, `CHAIN_NAME`, `CHAIN_SYMBOL` `FUND_HOLDER_x` in `ibftconf.json` file
        + Example `FUND_HOLDER_x`: `0373F5b03cE080EA25FB719ABb35bBc098c4f517`. This is the wallet will be used to hold
          chain tokens. You can use any wallet address you want. But make sure you have the private key of that wallet.
    + Update `network_config/nodeconf.toml` file:
        + Correct enode address. The public node id the node public key, excluding the initial `0x`
        + Example `NODE_1_KEY_PUB`: https://besu.hyperledger.org/stable/public-networks/concepts/node-keys#enode-url

- Upload some config files in `network_config` folder to AWS Secrets Manager as Plaintext:
    - `networkFiles/genesis.json` file to AWS with name `testnet-nchaincore-genesis`
    - `networkFiles/nodeconf.toml` file to AWS with name `testnet-nchaincore-nodeconf`
    - encrypt(`networkFiles/[wallet-node-1]/key`) file to AWS with name `testnet-nchaincore-node1-key`
    - encrypt(`networkFiles/[wallet-node-2]/key`) file to AWS with name `testnet-nchaincore-node2-key`
    - encrypt(`networkFiles/[wallet-node-3]/key`) file to AWS with name `testnet-nchaincore-node3-key`
    - encrypt(`networkFiles/[wallet-node-4]/key`) file to AWS with name `testnet-nchaincore-node4-key`

**NOTE**: Use this tool (https://dapp.nhancv.com/aes) to encrypt the wallet key before upload content to AWS. The
encrypt key will be uploaded to Terraform Cloud variable.

### Deploy

- Review and update local Terraform variables in `env.tf` file:
    + env=testnet
    + project=nchaincore
- Config Terraform variables on Terraform cloud:
    + AWS_ACCESS_KEY (sensitive) -> From `aws-tf-nchain` IAM user
    + AWS_SECRET_KEY (sensitive) -> From `aws-tf-nchain` IAM user
    + public_key_pair_bastion (sensitive) = content of `key_pairs/testnet-nchaincore-bastion.pub` file
    + public_key_pair_project (sensitive) = content of `key_pairs/testnet-nchaincore-project.pub` file
    + ethstats_secret (sensitive)
    + encrypt_key (sensitive)
    + domain_zone_id = From AWS Console -> Route53 -> Selected domain -> Copy `Hosted zone ID`
    + domain_rpc = `rpc.nhancv.com`
    + domain_nodes = `HCL ["1.node.nhancv.com", "2.node.nhancv.com", "3.node.nhancv.com", "4.node.nhancv.com"]`
    + domain_stats_https = `stats.nhancv.com`
    + domain_stats_push = `push.stats.nhancv.com`

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

- Verify p2p

```
- Access to bastion host
- Access to private host
telnet 1.node.nhancv.com 30303
wget --spider localhost:8545
```

- Verify rpc

```
Get latest block number:
curl -X POST --data '{"jsonrpc":"2.0","method":"eth_getBlockByNumber","params":["latest", false],"id":1}' https://rpc.nhancv.com

Get total validators addresses:
curl -X POST --data '{"jsonrpc":"2.0","method":"ibft_getValidatorsByBlockNumber","params":["latest"], "id":1}' https://rpc.nhancv.com

Get gas price:
curl -X POST --data '{"jsonrpc":"2.0","method":"eth_gasPrice","params":["latest"], "id":1}' https://rpc.nhancv.com

```

- Verify ethstats

Access https://stats.nhancv.com

### Access to bastion host

```
chmod 600 key_pairs/testnet-nchaincore-bastion
ssh -i key_pairs/testnet-nchaincore-bastion ubuntu@<bastion_public_ip>

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

