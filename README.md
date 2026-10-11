# AWS Dev Environment with Terraform

Infrastructure as Code project that provisions a complete development environment on AWS using Terraform: a custom VPC, a public subnet with internet access, a security group, an SSH key pair, and an Ubuntu 24.04 EC2 instance that installs Docker on first boot and adds itself to my local SSH config for one-command access.

I built this to rebuild, as code, the VPC and EC2 patterns I first created by hand in the AWS console and CLI (see my [AWS Beginner Roadmap](https://github.com/Bla-vk/AWS-Beginner-Roadmap)). One `terraform apply` now creates in about a minute what took many manual steps before.

**Result:** 9 resources created, server reachable over SSH, Docker running, then everything removed cleanly with `terraform destroy`.

---

## Table of Contents

- [Architecture](#architecture)
- [What It Builds](#what-it-builds)
- [Project Structure](#project-structure)
- [How It Works](#how-it-works)
- [Prerequisites](#prerequisites)
- [Usage](#usage)
- [Results](#results)
- [Troubleshooting](#troubleshooting)
- [Security Notes](#security-notes)
- [Skills Demonstrated](#skills-demonstrated)
- [What I Learned](#what-i-learned)
- [Next Steps](#next-steps)

---

## Architecture

```
                    Internet
                       |
              [ Internet Gateway ]  dev-igw
                       |
        +------ VPC dev (10.100.0.0/16) ------+
        |                                     |
        |   Public route table                |
        |   0.0.0.0/0 -> IGW                  |
        |        |                            |
        |   [ Public subnet 10.100.1.0/24 ]   |
        |   eu-west-2a                        |
        |        |                            |
        |   [ EC2 dev-node ]  <- dev-sg       |
        |   Ubuntu 24.04, t3.micro, Docker    |
        +-------------------------------------+
```

---

## What It Builds

| Resource | Name | Purpose |
|---|---|---|
| VPC | `dev` | Isolated network, CIDR `10.100.0.0/16`, DNS support and hostnames enabled |
| Public subnet | `dev-public-subnet` | `10.100.1.0/24` in `eu-west-2a`, auto-assigns public IPs |
| Internet Gateway | `dev-igw` | Gives the VPC a path to the internet |
| Route table | `dev-public-route-table` | Holds the public routing rules |
| Route | `0.0.0.0/0` | Sends internet-bound traffic to the Internet Gateway |
| Route table association | n/a | Attaches the route table to the public subnet |
| Security group | `dev-sg` | Controls traffic to the instance (see [Security Notes](#security-notes)) |
| Key pair | `main-key` | Registers my local public SSH key with AWS |
| EC2 instance | `dev-node` | `t3.micro`, Ubuntu 24.04 LTS, 10 GB gp3 root volume, Docker installed at boot |

---

## Project Structure

```
.
├── providers.tf           # Terraform and AWS provider configuration
├── main.tf                # VPC, networking, security group, key pair, EC2 instance
├── datasources.tf         # Looks up the latest Ubuntu 24.04 AMI
├── variables.tf           # Input variables (host_os)
├── outputs.tf             # Exposes the instance public IP
├── userdata.tpl           # First-boot script that installs Docker Engine
├── linux-ssh-config.tpl   # SSH config template appended to ~/.ssh/config
├── .gitignore             # Keeps state, keys and secrets out of Git
└── screenshots/           # Evidence of each stage of the build
```

Each file has one job, which keeps the project easy to read and extend.

---

## How It Works

**providers.tf** pins the AWS provider to `~> 6.0`, sets the region to `eu-west-2` (London), and authenticates through a named local profile (`vscode`), so no credentials are ever written in code.

**datasources.tf** uses an `aws_ami` data source to find the most recent Ubuntu 24.04 (Noble) image published by Canonical (owner `099720109477`). The AMI ID is never hardcoded, so each run uses a current image.

**main.tf** builds the network first, then the compute:

1. Creates the VPC and a public subnet.
2. Creates the Internet Gateway, a route table and a default route to the gateway, then associates the route table with the subnet. This is what makes the subnet public.
3. Creates the security group and the key pair (reading the public key from `~/.ssh/mainkey.pub`).
4. Launches the EC2 instance using the AMI from the data source, the key pair, the security group and a `user_data` script.
5. Runs a `local-exec` provisioner once the instance exists. It renders an SSH config template with the instance's public IP and appends it to my local `~/.ssh/config`, so I can connect without looking up the IP.

**userdata.tpl** is a bash script EC2 runs once on first boot. It installs Docker Engine from Docker's official apt repository:

1. Updates packages and installs `ca-certificates`, `curl` and `gnupg`.
2. Adds Docker's GPG key and apt repository, so signed official packages are used.
3. Installs `docker-ce`, `docker-ce-cli` and `containerd.io`.
4. Adds the `ubuntu` user to the `docker` group, so Docker works without `sudo`.

`set -e` makes the script stop at the first failing command instead of continuing half-configured.

**linux-ssh-config.tpl** is the template the provisioner fills in. Terraform supplies the public IP, login user and key path, and appends this block to `~/.ssh/config`:

```
Host <public ip>
  Hostname <public ip>
  User ubuntu
  IdentityFile ~/.ssh/mainkey
```

Tools such as VS Code Remote-SSH and plain `ssh` can then connect straight away. The block is appended on every create, so after `terraform destroy` I remove the old `Host` entry by hand.

**variables.tf** defines `host_os` (default `linux`), which selects the SSH config template and shell interpreter used by the provisioner. Only the Linux template (`linux-ssh-config.tpl`) is included, so a `windows-ssh-config.tpl` would be needed to run this on Windows.

**outputs.tf** prints the instance's public IP after `apply`.

Terraform resolves references such as `aws_vpc.main_vpc.id` into a dependency graph, so it creates everything in the correct order automatically.

---

## Prerequisites

- Terraform installed (`terraform -version`)
- An AWS account and the AWS CLI configured with a profile named `vscode` (or edit `providers.tf` to match yours)
- An SSH key pair generated locally:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/mainkey
```

This creates `~/.ssh/mainkey` (private, never share or commit) and `~/.ssh/mainkey.pub` (public, uploaded to AWS by Terraform).

---

## Usage

```bash
# 1. Download the AWS provider and initialise the working directory
terraform init

# 2. Format and validate the configuration
terraform fmt
terraform validate

# 3. Preview what will be created
terraform plan

# 4. Create the infrastructure
terraform apply

# 5. Show the instance's public IP
terraform output dev_ip

# 6. Connect (wait 2 to 3 minutes for first-boot setup to finish)
ssh -i ~/.ssh/mainkey ubuntu@<dev_ip>

# 7. Verify Docker was installed by user_data
cloud-init status
docker --version
docker run hello-world

# 8. Destroy everything when finished to avoid charges
terraform destroy
```

After `terraform destroy`, delete the old `Host` block for that IP from `~/.ssh/config`.

---

## Results

### 1. `terraform plan`
Terraform previews the resources it will create before changing anything: **9 to add, 0 to change, 0 to destroy**.

![terraform plan](screenshots/01-terraform-plan.png)

### 2. `terraform apply`
All 9 resources are created, and the instance's public IP is returned as an output.

![terraform apply](screenshots/02-terraform-apply.png)

### 3. SSH into the instance
Connecting to the new Ubuntu 24.04 server with the key pair Terraform registered.

![ssh session](screenshots/03-ssh-session.png)

### 4. Docker installed by `user_data`
`cloud-init status` reports `done`, and Docker 29.9.0 runs the `hello-world` container, confirming the bootstrap script worked with no manual setup.

![docker hello-world](screenshots/04-docker-hello-world.png)

### 5. EC2 instance in the AWS console
`dev-node` is running with 3/3 status checks passed.

![ec2 instance](screenshots/05-ec2-instance.png)

### 6. VPC in the AWS console
The `dev` VPC with DNS resolution and DNS hostnames enabled.

![vpc](screenshots/06-vpc.png)

### 7. Public subnet in the AWS console
`dev-public-subnet` (`10.100.1.0/24`) in `eu-west-2a`.

![public subnet](screenshots/07-public-subnet.png)

### 8. `terraform destroy`
All 9 resources are removed cleanly, leaving nothing running or billing in the account.

![terraform destroy](screenshots/08-terraform-destroy.png)

---

## Troubleshooting

Problems I hit while building this, and what fixed them:

| Problem | Cause | Fix |
|---|---|---|
| `docker: command not found` after SSH | `user_data` runs in the background after boot, and can fail or not run at all | Run `cloud-init status` and wait for `done`. Read `/var/log/cloud-init-output.log` for the failing command |
| `user_data` edits have no effect | `user_data` only runs on first boot, and the instance is not replaced when it changes | Set `user_data_replace_on_change = true`, or run `terraform apply -replace=aws_instance.dev_node` |
| SSH or VS Code Remote-SSH times out | The saved IP belonged to an instance that no longer existed (after a destroy or stop/start the public IP changes) | Run `terraform output dev_ip`, confirm the instance is running, and remove stale `Host` entries from `~/.ssh/config` |
| `permission denied` running `docker` | Group membership only applies to new login sessions | Log out and back in |

---

## Security Notes

This is a learning environment, and a few choices are intentionally simple. Before using this pattern for anything real, I would change the following:

- **The security group is fully open.** `dev-sg` allows all inbound traffic from `0.0.0.0/0`. In a real environment I would allow only SSH (port 22) from my own IP, plus only the ports the application needs. This is the first thing I would harden.
- **Credentials stay out of the code.** Authentication uses a local named profile, and the private key never leaves my machine.
- **State and secrets stay out of Git.** `terraform.tfstate` can contain sensitive values, so the `.gitignore` excludes state files, `.terraform/`, `*.tfvars`, keys and `.env` files. `.terraform.lock.hcl` is committed so provider versions stay consistent. For team use, state would move to a remote backend such as S3 with locking.
- **Screenshots are redacted.** My home IP and AWS account ID are covered.

---

## Skills Demonstrated

Terraform, Infrastructure as Code, Amazon VPC, subnets, route tables, Internet Gateways, Security Groups, EC2, SSH key management, data sources, input variables and outputs, `user_data` bootstrapping, Docker Engine installation on Ubuntu, Linux package management, `local-exec` provisioners, `templatefile` rendering, SSH config automation, troubleshooting with cloud-init logs, secrets hygiene with `.gitignore`

---

## What I Learned

- Terraform's workflow (`init`, `plan`, `apply`, `destroy`) gives a repeatable, reviewable way to build infrastructure compared with clicking through the console.
- Resource references create implicit dependencies, so Terraform orders creation without manual sequencing.
- `user_data` automates server setup at launch, so the instance is ready to run containers with no manual steps, but it only runs once and needs log checking when it fails.
- Data sources are better than hardcoded values for things like AMI IDs that change over time.
- Variables let one codebase work across operating systems.
- State tracks real infrastructure, so it must be protected and kept out of version control.
- Public IPs change when instances are replaced, so stale SSH config entries are a common cause of connection timeouts.

---

## Next Steps

- Restrict the security group to SSH from my IP only
- Run a containerised app on the instance and expose only its port
- Add a private subnet and NAT gateway
- Move state to a remote S3 backend with locking
- Refactor into reusable modules
- Add a GitHub Actions workflow to run `terraform fmt` and `terraform validate` on every push
