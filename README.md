# Vault SSH Signing Setup

A complete setup script for HashiCorp Vault with SSH certificate signing and AppRole authentication capabilities.

## 🚀 Quick Start

```bash
# Download and run the setup script
chmod +x vault-ssh-setup.sh
./vault-ssh-setup.sh
```

The script will automatically:
- Install Vault if not present
- Configure and initialize Vault
- Set up SSH signing capabilities
- Create AppRole authentication
- Test the complete setup

## 📋 Prerequisites

- **Operating System**: Linux or macOS
- **Dependencies**: `jq` (auto-installed by script)
- **Permissions**: sudo access for Vault installation
- **Network**: Port 8200 available

## 🏗️ Architecture Overview

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Client App    │    │      Vault      │    │   SSH Server    │
│                 │    │                 │    │                 │
│ 1. AppRole Auth ├────► 2. Get Token    │    │                 │
│ 3. Request Cert │    │ 4. Sign/Issue   │    │                 │
│ 5. Use Cert     ├────┼─────────────────┼────► 6. Validate     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 🔧 What the Script Configures

### 1. Vault Installation & Configuration
- **Storage**: File-based storage in `./vault-data`
- **Listener**: HTTP on `127.0.0.1:8200` (TLS disabled for dev)
- **UI**: Enabled and accessible
- **API Address**: `http://127.0.0.1:8200`

### 2. Authentication Methods
- **AppRole**: Enabled for programmatic access
- **Role Name**: `ssh-client`
- **Token TTL**: 1 hour (max 4 hours)
- **Secret ID TTL**: 24 hours

### 3. SSH Secrets Engine
- **Mount Path**: `ssh/`
- **CA Type**: Internal CA with auto-generated signing key
- **Role Name**: `ssh-signer`
- **Capabilities**: User and host certificate signing + key pair generation

### 4. Policies
```hcl
# SSH signing policy
path "ssh/sign/ssh-signer" {
  capabilities = ["create", "update"]
}

# SSH key pair generation
path "ssh/issue/ssh-signer" {
  capabilities = ["create", "update"]
}

path "ssh/public_key" {
  capabilities = ["read"]
}

path "ssh/config/ca" {
  capabilities = ["read"]
}
```

#### Policy Breakdown

| Path | Capabilities | Description |
|------|-------------|-------------|
| `ssh/sign/ssh-signer` | `["create", "update"]` | Sign existing SSH public keys to create certificates |
| `ssh/issue/ssh-signer` | `["create", "update"]` | Generate complete SSH key pairs with certificates |
| `ssh/public_key` | `["read"]` | Read the SSH CA public key for server configuration |
| `ssh/config/ca` | `["read"]` | Read SSH CA configuration and public key details |

## 📁 Generated Files

After successful setup, you'll have:

```
├── vault-config.hcl          # Vault server configuration
├── vault-data/               # Vault storage directory
├── vault.log                 # Vault server logs
├── vault.pid                 # Process ID file
├── vault-root-token          # Root token (keep secure!)
├── approle-role-id           # AppRole Role ID
└── approle-secret-id         # AppRole Secret ID
```

## 🔐 SSH Role Configuration

The `ssh-signer` role is configured with:

| Setting | Value | Description |
|---------|--------|-------------|
| `key_type` | `ca` | Certificate Authority signing |
| `algorithm_signer` | `rsa-sha2-256` | Signing algorithm |
| `allow_user_certificates` | `true` | Can sign user certificates |
| `allow_host_certificates` | `true` | Can sign host certificates |
| `allowed_users` | `*` | Any username allowed |
| `allowed_domains` | `*` | Any domain allowed |
| `default_user` | `ec2-user` | Default username |
| `ttl` | `30m` | Default certificate lifetime |
| `max_ttl` | `1h` | Maximum certificate lifetime |

## 🔑 Usage Examples

### 1. Authenticate with AppRole

```bash
export VAULT_ADDR=http://127.0.0.1:8200

# Get credentials from files
ROLE_ID=$(cat approle-role-id)
SECRET_ID=$(cat approle-secret-id)

# Login and get client token
CLIENT_TOKEN=$(vault write -field=token auth/approle/login \
    role_id=$ROLE_ID \
    secret_id=$SECRET_ID)

export VAULT_TOKEN=$CLIENT_TOKEN
```

### 2. Sign an Existing SSH Public Key

```bash
# Sign your existing public key
vault write -field=signed_key ssh/sign/ssh-signer \
    public_key=@~/.ssh/id_rsa.pub > ~/.ssh/id_rsa-cert.pub

# Use the certificate
ssh -i ~/.ssh/id_rsa -o CertificateFile=~/.ssh/id_rsa-cert.pub user@server
```

### 3. Generate a Complete SSH Key Pair

```bash
# Generate private key, public key, and signed certificate
vault write -format=json ssh/issue/ssh-signer \
    valid_principals=ec2-user,ubuntu \
    ttl=30m > keypair.json

# Extract components
jq -r '.data.private_key' keypair.json > private_key
jq -r '.data.signed_key' keypair.json > certificate
# Note: signed_key contains the certificate, not just public key

chmod 600 private_key

# Use the generated key pair
ssh -i private_key -o CertificateFile=certificate user@server
```

### 4. Get SSH CA Public Key (for SSH servers)

```bash
# Get the CA public key for SSH server configuration
vault read -field=public_key ssh/config/ca > /etc/ssh/trusted_ca_keys

# Add to SSH server config (/etc/ssh/sshd_config)
echo "TrustedUserCAKeys /etc/ssh/trusted_ca_keys" >> /etc/ssh/sshd_config
systemctl reload sshd
```

## 🖥️ Target SSH Server Configuration

To accept Vault-signed certificates, configure the target SSH servers:

### 1. Get the CA Public Key

On your Vault server, extract the CA public key:

```bash
export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_TOKEN=$(cat vault-root-token)

# Save CA public key to a file
vault read -field=public_key ssh/config/ca > vault_ca.pub

# Copy this key to your target servers
scp vault_ca.pub target-server:/tmp/vault_ca.pub
```

### 2. Configure Target SSH Server

On each target SSH server that should accept Vault certificates:

```bash
# Copy CA public key to SSH directory
sudo cp /tmp/vault_ca.pub /etc/ssh/trusted_user_ca_keys
sudo chmod 644 /etc/ssh/trusted_user_ca_keys
sudo chown root:root /etc/ssh/trusted_user_ca_keys
```

### 3. Update SSH Server Configuration

Edit `/etc/ssh/sshd_config` on the target server:

```bash
sudo vim /etc/ssh/sshd_config
```

Add these lines:

```bash
# Trust certificates signed by Vault CA
TrustedUserCAKeys /etc/ssh/trusted_user_ca_keys

# Optional: Require certificate authentication (disable password auth)
PasswordAuthentication no
PubkeyAuthentication yes
AuthorizedKeysFile none

# Optional: Log certificate details
LogLevel VERBOSE

# Optional: Allow specific principals only
# AuthorizedPrincipalsFile /etc/ssh/auth_principals/%u
```

### 4. Restart SSH Service

```bash
# Test configuration first
sudo sshd -t

# If test passes, restart SSH
sudo systemctl restart sshd
# or
sudo service ssh restart
```

### 5. Verify Configuration

```bash
# Check SSH server status
sudo systemctl status sshd

# View SSH logs
sudo tail -f /var/log/auth.log
# or
sudo journalctl -u sshd -f
```

## 🧪 Testing SSH Certificate Authentication

### Complete End-to-End Test

1. **Generate certificate on Vault server:**
```bash
export VAULT_ADDR=http://127.0.0.1:8200
ROLE_ID=$(cat approle-role-id)
SECRET_ID=$(cat approle-secret-id)
CLIENT_TOKEN=$(vault write -field=token auth/approle/login role_id=$ROLE_ID secret_id=$SECRET_ID)
export VAULT_TOKEN=$CLIENT_TOKEN

# Generate key pair with certificate
vault write -format=json ssh/issue/ssh-signer \
    valid_principals=ec2-user,ubuntu,admin \
    ttl=5m > test_keypair.json

# Extract private key and certificate
jq -r '.data.private_key' test_keypair.json > test_private_key
jq -r '.data.signed_key' test_keypair.json > test_certificate
chmod 600 test_private_key
```

2. **Test connection to target server:**
```bash
# Connect using certificate
ssh -i test_private_key -o CertificateFile=test_certificate ec2-user@target-server

# Verify certificate details
ssh-keygen -L -f test_certificate
```

3. **Check SSH server logs on target:**
```bash
# On target server, watch authentication logs
sudo tail -f /var/log/auth.log | grep sshd
```

You should see logs like:
```
sshd[1234]: Accepted publickey for ec2-user from 1.2.3.4 port 12345 ssh2: RSA-CERT ID vault-userpass-1234567890
```

### Alternative: Sign Existing Key

If you prefer to sign an existing key:

```bash
# On client machine, generate or use existing key
ssh-keygen -t rsa -f ~/.ssh/vault_test_key -N ""

# Sign the public key using Vault
vault write -field=signed_key ssh/sign/ssh-signer \
    public_key=@~/.ssh/vault_test_key.pub > ~/.ssh/vault_test_key-cert.pub

# Connect using signed certificate
ssh -i ~/.ssh/vault_test_key -o CertificateFile=~/.ssh/vault_test_key-cert.pub ec2-user@target-server
```

## 🔧 Advanced SSH Server Configuration

### Principal-Based Access Control

Create user-specific principal files:

```bash
# Create principals directory
sudo mkdir -p /etc/ssh/auth_principals

# Create principal file for specific user
echo "admin" | sudo tee /etc/ssh/auth_principals/ec2-user
echo "developer" | sudo tee /etc/ssh/auth_principals/ubuntu

# Update sshd_config
echo "AuthorizedPrincipalsFile /etc/ssh/auth_principals/%u" | sudo tee -a /etc/ssh/sshd_config
```

### Certificate Validation Options

Add to `/etc/ssh/sshd_config`:

```bash
# Require valid certificate (no fallback to authorized_keys)
AuthorizedKeysFile none

# Allow both certificates and authorized_keys
AuthorizedKeysFile /etc/ssh/authorized_keys/%u

# Certificate options
CertificateFile /etc/ssh/ssh_host_rsa_key-cert.pub
HostCertificate /etc/ssh/ssh_host_rsa_key-cert.pub
```

### Troubleshooting SSH Certificate Issues

**1. Check certificate validity:**
```bash
ssh-keygen -L -f certificate_file
```

**2. Test SSH connection with verbose output:**
```bash
ssh -vvv -i private_key -o CertificateFile=certificate user@server
```

**3. Common issues:**
- **Certificate expired**: Check TTL and regenerate
- **Principal mismatch**: Ensure certificate principals match server expectations  
- **CA key mismatch**: Verify target server has correct CA public key
- **Permission issues**: Check file permissions (600 for private keys, 644 for certificates)

**4. SSH server debug mode:**
```bash
# Stop SSH service
sudo systemctl stop sshd

# Run in debug mode
sudo /usr/sbin/sshd -D -d

# In another terminal, try to connect
ssh -i private_key -o CertificateFile=certificate user@localhost
```

## 🛠️ Management Commands

### Vault Server Management
```bash
# Check Vault status
vault status

# View logs
tail -f vault.log

# Stop Vault
kill $(cat vault.pid)

# Start Vault (after stopping)
vault server -config=vault-config.hcl &
echo $! > vault.pid
```

### Token Management
```bash
# Check token info
vault token lookup

# Renew token
vault token renew

# Create new secret ID
vault write -field=secret_id auth/approle/role/ssh-client/secret-id
```

## 🔍 Troubleshooting

### Common Issues

**1. Vault fails to start**
```bash
# Check logs
cat vault.log

# Verify port availability
lsof -i :8200

# Check permissions
ls -la vault-data/
```

**2. AppRole authentication fails**
```bash
# Verify credentials
vault read auth/approle/role/ssh-client
cat approle-role-id
cat approle-secret-id

# Check if auth method is enabled
vault auth list
```

**3. SSH signing fails**
```bash
# Check SSH engine status
vault secrets list

# Verify role configuration
vault read ssh/roles/ssh-signer

# Check policy permissions
vault policy read ssh-signer
```

**4. Certificate validation issues**
```bash
# Verify certificate format
ssh-keygen -L -f certificate_file

# Check CA public key
vault read -field=public_key ssh/config/ca

# Validate certificate against CA
ssh-keygen -Y verify -f ca_public_key -I principal -n namespace -s signature
```

### Debug Mode

Enable debug logging by modifying `vault-config.hcl`:

```hcl
log_level = "debug"
```

Then restart Vault and check `vault.log` for detailed information.

## 🔒 Security Considerations

### Development vs Production

This setup is designed for **development and testing**. For production:

1. **Enable TLS**: Configure proper SSL certificates
2. **Use external storage**: PostgreSQL, Consul, etc.
3. **Enable audit logging**: Track all operations
4. **Implement proper secret management**: Don't store tokens in files
5. **Network security**: Firewall rules, VPN access
6. **Regular token rotation**: Automate token renewal
7. **Principle of least privilege**: More restrictive policies

### Security Best Practices

```bash
# 1. Secure file permissions
chmod 600 vault-root-token approle-*
chown vault:vault vault-data/

# 2. Regular token rotation
vault write -f auth/approle/role/ssh-client/secret-id

# 3. Monitor access
vault audit enable file file_path=vault-audit.log

# 4. Use short-lived certificates
vault write ssh/roles/ssh-signer ttl=5m max_ttl=15m
```

## 🧪 Testing Your Setup

### Manual Verification

```bash
# 1. Test AppRole login
ROLE_ID=$(cat approle-role-id)
SECRET_ID=$(cat approle-secret-id)
TOKEN=$(vault write -field=token auth/approle/login role_id=$ROLE_ID secret_id=$SECRET_ID)
echo "Token obtained: ${TOKEN:0:10}..."

# 2. Test SSH signing
export VAULT_TOKEN=$TOKEN
ssh-keygen -t rsa -f test_key -N ""
vault write -field=signed_key ssh/sign/ssh-signer public_key=@test_key.pub > test_cert.pub
ssh-keygen -L -f test_cert.pub

# 3. Test key generation
vault write -format=json ssh/issue/ssh-signer valid_principals=testuser ttl=5m
```

### Automated Testing

The setup script includes comprehensive testing that verifies:
- ✅ Vault installation and startup
- ✅ Initialization and unsealing
- ✅ AppRole authentication
- ✅ SSH certificate signing
- ✅ SSH key pair generation
- ✅ Certificate validation

## 📚 Additional Resources

- [HashiCorp Vault Documentation](https://www.vaultproject.io/docs)
- [SSH Secrets Engine Guide](https://www.vaultproject.io/docs/secrets/ssh)
- [AppRole Authentication](https://www.vaultproject.io/docs/auth/approle)
- [SSH Certificate Authentication](https://man.openbsd.org/ssh-keygen.1#CERTIFICATES)

## 🤝 Contributing

Feel free to submit issues and enhancement requests!

## 📄 License

This project is licensed under the MIT License.