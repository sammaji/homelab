# oracle-vm setup

One-time steps before `terraform apply`.

## 1. Account

Sign up at <https://signup.cloud.oracle.com>. Your **home region** is chosen at
signup and can't be changed - Always Free A1 compute only exists there, so put
that region in `terraform.tfvars`. Optionally upgrade to Pay As You Go
(Billing -> Upgrade and Manage Payment) for better A1 availability; Always
Free resources stay free.

## 2. API key + `~/.oci/config`

Easiest is the OCI CLI:

```bash
brew install oci-cli
oci setup config        # prompts for user OCID, tenancy OCID, region; generates the key pair
```

When it asks for a key passphrase, enter `N/A`. Terraform can't prompt for
one, so an encrypted key makes `plan` fail. To strip a passphrase from an
existing key (same key, same fingerprint, no re-upload). Run it in a real
terminal, because it prompts:

```bash
openssl pkey -in ~/.oci/oci_api_key.pem -out ~/.oci/oci_api_key.nopass.pem \
  && mv ~/.oci/oci_api_key.nopass.pem ~/.oci/oci_api_key.pem && chmod 600 ~/.oci/oci_api_key.pem
echo OCI_API_KEY >> ~/.oci/oci_api_key.pem   # label line OCI recommends; silences the CLI warning
```

Then upload the generated public key: Console -> Profile (top right) -> My
profile -> API keys -> Add API key -> Paste public key
(`~/.oci/oci_api_key_public.pem`).

Or manually: Console -> My profile -> API keys -> Add API key -> Generate, then
paste the shown config snippet into `~/.oci/config` and save the private key
to the `key_file` path it references.

Verify:

```bash
oci iam region-subscription list   # should succeed and show your home region with is-home-region: true
```

## 3. OCIDs

- Tenancy OCID: Profile -> Tenancy: <name> -> OCID (also in `~/.oci/config`)
- Compartment OCID (optional): Identity -> Compartments. Leave unset to use the
  root compartment.

## 4. SSH key

The VMs get `~/.ssh/id_ed25519.pub` by default. Generate one if needed:

```bash
ssh-keygen -t ed25519
```
