# 🔑 Keycloak 26.3.1 Installation & IAM Capabilities Guide | Ubuntu 22.04.5 LTS

> **Enterprise Identity and Access Management for DevOps**  
> Production-ready Keycloak setup with PostgreSQL backend, TLS encryption, systemd management, and comprehensive IAM capabilities (Authentication, Authorization, Accounting). Follows security best practices for identity infrastructure.

---

## 📋 Prerequisites

| Requirement | Version | Verification Command |
|-------------|---------|----------------------|
| OS | Ubuntu 22.04.5 LTS | `lsb_release -a` |
| Java | OpenJDK 17 | `java -version` |
| Database | PostgreSQL 14+ | `psql --version` |
| Disk Space | 2 GB minimum | `df -h /` |
| RAM | 2 GB minimum | `free -h` |

> ⚠️ **Security Note**: Never run Keycloak as root. Always use a dedicated service account.

---

## 🔧 Installation Steps

### 1. Install Java 17
```bash
sudo apt update
sudo apt install -y openjdk-17-jdk
java -version  # Verify: openjdk version "17.x"
```

### 2. Install & Configure PostgreSQL
```bash
# Install PostgreSQL
sudo apt install -y postgresql postgresql-contrib

# Start and enable service
sudo systemctl enable --now postgresql

# Create Keycloak database and user
sudo -u postgres psql <<EOF
CREATE DATABASE keycloak WITH ENCODING 'UTF8' LC_COLLATE='en_US.UTF-8' LC_CTYPE='en_US.UTF-8' TEMPLATE=template0;
CREATE USER keycloak WITH PASSWORD 'STRONG_PASSWORD_HERE';  # ← CHANGE THIS
GRANT ALL PRIVILEGES ON DATABASE keycloak TO keycloak;
\q
EOF
```

> 🔐 **Critical**: Replace `STRONG_PASSWORD_HERE` with a 20+ character password generated via `openssl rand -base64 24`

---

### 3. Download & Deploy Keycloak
```bash
# Download official distribution
cd /tmp
wget https://github.com/keycloak/keycloak/releases/download/26.3.1/keycloak-26.3.1.zip

# Extract and install to standard location
sudo unzip keycloak-26.3.1.zip -d /opt/
sudo mv /opt/keycloak-26.3.1 /opt/keycloak

# Create dedicated service user (never run as root!)
sudo useradd -r -s /usr/sbin/nologin -d /opt/keycloak keycloak
sudo chown -R keycloak:keycloak /opt/keycloak
```

---

### 4. Generate TLS Certificates
> ⚠️ **Production Warning**: Self-signed certificates are for **testing only**. In production:
> - Use certificates from trusted CA (Let's Encrypt, DigiCert, etc.)
> - Store keys with strict permissions (`chmod 400 *.pem`)

```bash
# Create certificate directory
sudo mkdir -p /opt/keycloak/certs
sudo chown keycloak:keycloak /opt/keycloak/certs

# Generate self-signed cert (TESTING ONLY)
sudo -u keycloak openssl req -x509 -newkey rsa:2048 -keyout /opt/keycloak/certs/server.key.pem \
  -out /opt/keycloak/certs/server.crt.pem -days 365 -nodes \
  -subj "/C=NL/ST=Noord-Holland/L=Amsterdam/O=DevOpsLab/OU=IAM/CN=your-domain.com"
```

---

### 5. Configure Keycloak (`/opt/keycloak/conf/keycloak.conf`)
```properties
# Database Configuration
db=postgres
db-username=keycloak
db-password=STRONG_PASSWORD_HERE  # ← MUST MATCH STEP 2
db-url=jdbc:postgresql://localhost:5432/keycloak

# TLS/HTTPS Configuration (MANDATORY - disable HTTP)
https-certificate-file=/opt/keycloak/certs/server.crt.pem
https-certificate-key-file=/opt/keycloak/certs/server.key.pem
https-port=8443
http-enabled=false

# Hostname Configuration (REQUIRED for production)
hostname=auth.your-domain.com  # ← SET TO YOUR ACTUAL DOMAIN
hostname-strict=true
hostname-strict-https=true

# Security Hardening
proxy-headers=xforwarded
log-level=INFO
```

> 🔒 **Critical Security Settings**:
> - `http-enabled=false` → Enforces HTTPS-only access
> - `hostname-strict*` → Prevents host header injection attacks
> - Never commit passwords to version control – use secrets management in production

---

### 6. Create Systemd Service (`/etc/systemd/system/keycloak.service`)
```ini
[Unit]
Description=Keycloak Identity and Access Management
After=network.target postgresql.service
Wants=postgresql.service

[Service]
Type=simple
User=keycloak
Group=keycloak
WorkingDirectory=/opt/keycloak
ExecStart=/opt/keycloak/bin/kc.sh start --optimized
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure
RestartSec=10
LimitNOFILE=1048576
LimitNPROC=512
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
```

> ✅ **Hardening Applied**:
> - Dedicated service user (`keycloak`)
> - Resource limits (`LimitNOFILE`, `LimitNPROC`)
> - Filesystem isolation (`PrivateTmp`, `ProtectSystem`)
> - Privilege dropping (`NoNewPrivileges`)

---

### 7. Start Keycloak Service
```bash
# Reload systemd and start service
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable --now keycloak

# Verify service status
sudo systemctl status keycloak
journalctl -u keycloak -f --since "1 min ago"  # Monitor logs
```

---

### 8. Create Initial Admin User
```bash
# Run as keycloak user (never as root!)
sudo -u keycloak /opt/keycloak/bin/kc.sh \
  build \
  --db=postgres \
  --db-url=jdbc:postgresql://localhost:5432/keycloak \
  --db-username=keycloak \
  --db-password='STRONG_PASSWORD_HERE'

sudo -u keycloak /opt/keycloak/bin/kc.sh \
  bootstrap-admin \
  --username admin \
  --password 'ADMIN_STRONG_PASSWORD'  # ← 20+ chars, store in vault
```

> ⚠️ **Critical Post-Setup Step**:  
> The bootstrap admin is **temporary**. After first login:
> 1. Create permanent admin user via UI (`Users` → `Add user`)
> 2. Assign `admin` role in `Realm roles` tab
> 3. Delete the bootstrap admin account

---

### 9. Access Keycloak Admin Console
```
URL: https://your-domain.com:8443/admin/master/console/
Credentials: admin / ADMIN_STRONG_PASSWORD
```

> 🔐 **First-login security checklist**:
> - [ ] Change admin password immediately
> - [ ] Create permanent admin account
> - [ ] Delete bootstrap admin account
> - [ ] Configure email server for password resets
> - [ ] Enable brute-force detection (`Realm Settings` → `Security Defenses`)
> - [ ] Set up backup procedures for database + config

---

## 🔐 Core IAM Capabilities (The "AAA" Triad)

### 🔐 Authentication (Who are you?)

| Capability | Implementation | DevOps Value |
|------------|----------------|--------------|
| **Single Sign-On (SSO)** | Supports OIDC, OAuth 2.0, SAML 2.0 protocols. Users authenticate once and access multiple applications via cryptographically signed JWT tokens. | Eliminates password fatigue; enables secure microservices authentication |
| **User Federation** | Integrates with LDAP/Active Directory (ports 389/636) without duplicating user data. Supports identity brokering for Google, GitHub, Facebook logins. | Centralizes identity management across hybrid environments |
| **Multi-Factor Auth (MFA)** | Built-in TOTP/HOTP support (Google Authenticator), password recovery flows, email verification. Configurable per client or realm. | Meets compliance requirements (SOC2, ISO27001); prevents credential compromise |

---

### 🔒 Authorization (What can you access?)

| Capability | Implementation | DevOps Value |
|------------|----------------|--------------|
| **Role-Based Access Control (RBAC)** | Define realm/client roles (e.g., `admin`, `deployer`, `viewer`). Assign to users/groups. Applications validate roles via tokens. | Enforces least-privilege access across Kubernetes, CI/CD pipelines, cloud consoles |
| **Fine-Grained Authorization** | Policy Decision Point (PDP) evaluates policies against resources/scopes. Issues Requesting Party Tokens (RPTs) with precise permissions. | Secures APIs at operation level (e.g., "user can GET /api/orders but not DELETE") |
| **Policy Types** | JavaScript, Role-based, User-based, Time-based, Client-based policies. Combine with AND/OR logic. | Models complex authorization scenarios (e.g., "MFA required for prod deployments after 5PM") |

---

### 📊 Accounting (What did you do?)

| Capability | Implementation | DevOps Value |
|------------|----------------|--------------|
| **Audit Logging** | Tracks logins, token issuance, admin actions. Configurable event listeners for User/Admin events. | Meets compliance audit requirements; enables security forensics |
| **Event Export** | Forward events to ELK Stack, Splunk, or SIEM via custom SPI providers or REST API polling. | Centralized security monitoring; anomaly detection via log analysis |
| **Session Management** | View active sessions, force logout, set idle/session timeouts per realm. | Rapid incident response (revoke compromised sessions in seconds) |

---

## ⚙️ Integration Scenarios

| Target System | Integration Method | Notes |
|---------------|-------------------|-------|
| **Kubernetes** | OIDC integration with kube-apiserver | Standard practice for securing containerized workloads; use `kubectl oidc-login` plugin |
| **VMware vCenter** | OIDC identity federation (vCenter 7+) | Requires custom claim mapping; not officially supported but feasible with configuration tweaks |
| **Network Devices** | RADIUS via `keycloak-radius-plugin` (community) | Works with Cisco, MikroTik; **no native TACACS+ support** |
| **Linux SSH** | PAM module (`kc-ssh-pam`) | Authenticates SSH logins against Keycloak; logs to `/var/log/kc-ssh-pam.log` |
| **Web Applications** | OIDC/OAuth 2.0 adapters (Java, Node.js, Python) | Official adapters available; enables SSO for custom apps |
| **Custom UI Themes** | Theme directory (`/opt/keycloak/themes/`) | Brand login pages per client/application; supports HTML/CSS/JS customization |

---

## ✅ Verification Checklist

| Check | Command/Verification |
|-------|----------------------|
| Service running | `systemctl is-active keycloak` → `active` |
| Listening on port | `ss -tulpn \| grep 8443` → `LISTEN` |
| Database connection | `journalctl -u keycloak \| grep -i "database"` → `connected` |
| HTTPS enforced | `curl -I http://localhost:8080` → `Connection refused` |
| TLS certificate | `openssl s_client -connect localhost:8443 -servername your-domain.com 2>/dev/null \| grep "CN="` |
| Admin API accessible | `curl -k https://localhost:8443/realms/master/.well-known/openid-configuration` → JSON config |

---

## 🛠️ Troubleshooting

| Issue | Solution |
|-------|----------|
| `Permission denied` on certs | `sudo chmod 400 /opt/keycloak/certs/*.pem && sudo chown keycloak:keycloak /opt/keycloak/certs/*` |
| Database connection failed | Verify PostgreSQL is running (`systemctl status postgresql`) and credentials match `keycloak.conf` |
| Service fails to start | Check logs: `journalctl -u keycloak -n 100 --no-pager` |
| Hostname validation errors | Ensure `hostname` in config matches DNS record and certificate CN/SAN |
| Admin console shows "temporary user" warning | Create permanent admin user → assign roles → delete bootstrap account |

---

## 🔗 Related Resources
- [Keycloak 26.3.1 Official Documentation](https://www.keycloak.org/documentation)
- [Server Administration Guide](https://www.keycloak.org/server/admin)
- [Production Hardening Guide](https://www.keycloak.org/server/hardening)
- [PostgreSQL Performance Tuning for Keycloak](https://www.keycloak.org/server/db)
- [CIS Keycloak Benchmark](https://www.cisecurity.org/cis-benchmarks/)
- [Keycloak GitHub Repository](https://github.com/keycloak/keycloak)
