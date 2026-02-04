# 🔒 How to Secure SSH Connection

A step-by-step guide to hardening SSH access when connecting to remote machines. These configurations apply primarily to OpenSSH server (`/etc/ssh/sshd_config`) but principles extend to most SSH implementations.

---

## ✅ Essential Hardening Steps

### 1. Change the Default SSH Port
Avoid port 22 to reduce automated bot attacks.

```bash
# /etc/ssh/sshd_config
Port 22222  # Choose a port between 1024–49151 (user ports)
```

> ⚠️ **Warning**: Before applying, ensure firewall rules allow the new port and test connectivity in a parallel session to avoid lockout.

---

### 2. Restrict User/Group Access
Limit SSH access to authorized users or groups only.

```bash
# /etc/ssh/sshd_config
AllowUsers alice bob@192.168.1.0/24
DenyUsers eve
AllowGroups ssh-users
DenyGroups contractors
```

---

### 3. Disable Root Login
Prevent direct root access to mitigate brute-force attacks on the most privileged account.

```bash
# /etc/ssh/sshd_config
PermitRootLogin no
```

> ✅ **Best Practice**: Users should log in with regular accounts and escalate privileges via `sudo`.

---

### 4. Enforce SSH Key-Based Authentication
Replace password authentication with cryptographic keys.

```bash
# /etc/ssh/sshd_config
PasswordAuthentication no
PubkeyAuthentication yes
```

**On client machine**:
```bash
# Generate key pair (with strong passphrase)
ssh-keygen -t ed25519 -a 100 -C "your_email@example.com"

# Copy public key to server
ssh-copy-id -p 22222 username@server-ip
```

> 🔑 **Critical**: Always protect private keys with strong passphrases.

---

### 5. Set Low Authentication Attempts
Limit brute-force opportunities.

```bash
# /etc/ssh/sshd_config
MaxAuthTries 3
```

---

### 6. Disable Empty Passwords
Prevent accounts with blank passwords from logging in.

```bash
# /etc/ssh/sshd_config
PermitEmptyPasswords no
```

---

### 7. Disable Weak Algorithms & Ciphers
Enforce modern cryptographic standards.

```bash
# /etc/ssh/sshd_config
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com
```

> ⚠️ Verify client compatibility before applying. Test with `ssh -Q cipher` and `ssh -Q kex`.

---

### 8. Enforce SSH Protocol Version 2
SSH-1 is obsolete and vulnerable.

```bash
# /etc/ssh/sshd_config
Protocol 2
```

---

### 9. Set Idle Session Timeout
Automatically terminate inactive sessions.

```bash
# /etc/ssh/sshd_config
ClientAliveInterval 360    # Send keepalive every 6 minutes
ClientAliveCountMax 0      # Terminate after first failed keepalive
```

---

## 🔁 Ongoing Security Practices

| Practice | Implementation |
|----------|----------------|
| **Rotate SSH Keys** | Periodically replace keys (especially for service accounts). Automate expiration where possible. |
| **Monitor Logs** | Review `/var/log/auth.log` or `journalctl -u sshd` for failed logins:<br>`sudo journalctl -f -u sshd` |
| **Implement Fail2Ban** | Automatically block IPs after repeated failed attempts:<br>`sudo apt install fail2ban` |
| **Use Port Knocking** | (Advanced) Hide SSH port behind a sequence of connection attempts. |

---

## 🛡️ Verification Checklist

After applying changes:

```bash
# 1. Validate config syntax BEFORE restarting
sudo sshd -t

# 2. Restart SSH service (keep existing session open!)
sudo systemctl restart sshd

# 3. Test NEW connection in separate terminal
ssh -p 22222 username@server-ip

# 4. Verify active connections
ss -tulpn | grep ':22222'
```

> ⚠️ **Never restart SSH without a fallback session** – you may lock yourself out permanently.

---

## 📚 Related Resources
- [OpenSSH Security Best Practices](https://www.openssh.com/security.html)
- [CIS OpenSSH Benchmark](https://www.cisecurity.org/cis-benchmarks/)
- `man sshd_config` – Official configuration documentation