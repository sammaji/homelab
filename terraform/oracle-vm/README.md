# oracle-vm

Provisions two Ampere A1 VMs on Oracle Cloud sized to use exactly the OCI
Always Free allowance, plus a budget that emails you on any actual spend.

## What this creates

- `oci_core_instance.this["prod"|"hlab"]` - `oracle-vm-prod` (side-project
  infra, public web) and `oracle-vm-hlab` (personal self-hosting, Tailscale
  only). `VM.Standard.A1.Flex`, **1 OCPU / 6GB RAM / 100GB boot volume
  each**, Ubuntu 24.04 (ARM), ephemeral public IP. Together that's exactly the Always Free A1 allowance (2 OCPU + 12GB RAM total, 200GB
  block storage total). Preconditions refuse to plan anything over it - you can
  reshape (e.g. 1x 2/12/200) but not exceed it.
- VCN `10.0.0.0/16` + public subnet + internet gateway. The subnet security
  list only allows egress + ICMP path-MTU. Ingress is per VM via NSGs:
  - `base` (both VMs): SSH from `ssh_allowed_cidrs` (default anywhere - drop
    to `[]` once Tailscale SSH works), UDP 41641 (Tailscale direct)
  - `web` (VMs with `public_web = true`, i.e. prod): TCP `public_tcp_ports`
    (default 80/443)

  There is deliberately no VCN-internal allow rule: the VMs reach each other
  over Tailscale, where ACLs keep prod away from hlab. See
  [`vm-tailscale-setup.md`](vm-tailscale-setup.md).
- `oci_budget_budget` + alert rules - emails `budget_alert_email` at 1% of
  `budget_amount` actual spend, and on forecast > budget.

The 2x `VM.Standard.E2.1.Micro` AMD instances are also Always Free, but their
boot volumes (min ~47GB each) would push block storage over 200GB alongside
the A1 boot volumes above, so they're left out.

> Oracle halved the A1 allowance from 4 OCPU / 24GB to 2 OCPU / 12GB on
> 2026-06-15, and started terminating over-limit Always Free instances on
> 2026-08-18. The docs say the new limit applies to all tenancies, including
> Pay As You Go.

## Free Tier vs Pay As You Go

Both get the same Always Free resources. On a pure **Free Tier** account
nothing can ever be billed - over-limit resources just fail to create. On
**Pay As You Go** you get much better A1 capacity (Free Tier accounts often hit
`Out of host capacity`) and Always Free resources stay at 0, but anything
outside the limits *is* billed - that's what the preconditions and budget
guard against. Oracle also reclaims idle Always Free instances (95th-percentile
CPU, network, and - for A1 - memory all under 20% over 7 days).

## Prerequisites

See [`SETUP.md`](SETUP.md) for creating the OCI API key and `~/.oci/config`.

## Usage

```bash
cd terraform/oracle-vm
cp terraform.tfvars.example terraform.tfvars   # fill in tenancy_ocid, region, email
terraform init
terraform plan
terraform apply
```

If apply fails with `Out of host capacity`, try another
`availability_domain_index` (regions with 3 ADs), retry later, or upgrade to
PAYG.

## After apply

Follow [`vm-tailscale-setup.md`](vm-tailscale-setup.md): join both VMs to the
tailnet, swap OCI's default iptables REJECT rules for ufw, then set
`ssh_allowed_cidrs = []` and re-apply to close public SSH.

Once that's done, SSH only works over Tailscale:

```bash
terraform output ssh_commands   # ssh ubuntu@oracle-vm-hlab / oracle-vm-prod
```

Break-glass if Tailscale is down: OCI Console -> Instance -> Console connection
(serial console, needs a password set for `ubuntu`).
