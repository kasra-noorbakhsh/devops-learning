# 📊 Zabbix 6.0 LTS Installation Guide | Ubuntu 20.04 (Focal)

> **Enterprise Monitoring for DevOps**  
> Production-ready Zabbix 6.0 LTS setup with MySQL backend, Apache frontend, and agent integration. Includes troubleshooting for common installation pitfalls and security hardening recommendations.

---

## 📋 Prerequisites

| Requirement | Specification | Verification Command |
|-------------|---------------|----------------------|
| OS | Ubuntu 20.04 LTS (Focal Fossa) | `lsb_release -a` |
| Architecture | x86_64 | `uname -m` |
| Disk Space | 5 GB minimum (SSD recommended) | `df -h /` |
| RAM | 2 GB minimum (4 GB+ for production) | `free -h` |
| Database | MySQL 8.0+ or MariaDB 10.3+ | `mysql --version` |
| Web Server | Apache 2.4+ | `apache2 -v` |

> ⚠️ **Critical Note**: Zabbix 6.0 LTS reaches end-of-life in **November 2026**. Plan migration to 7.0 LTS for long-term support.

---

## 🔧 Installation Steps

### 1. Install Required Dependencies
```bash
sudo apt update
sudo apt install -y apache2 php php-mysqlnd php-curl php-gd php-mbstring \
  php-xml php-bcmath php-ldap php-opcache mysql-server mysql-client \
  unzip curl wget
```

> 🔒 **Security Hardening**: After PHP installation, disable dangerous functions in `/etc/php/7.4/apache2/php.ini`:
> ```ini
> disable_functions = exec,passthru,shell_exec,system,proc_open,popen
> ```

---

### 2. Secure MySQL Installation
```bash
# Start MySQL service
sudo systemctl enable --now mysql

# Run security hardening wizard
sudo mysql_secure_installation
```

> ✅ **During wizard**:
> - Set root password (use `openssl rand -base64 24` for strong password)
> - Remove anonymous users → **Yes**
> - Disallow root remote login → **Yes**
> - Remove test database → **Yes**
> - Reload privilege tables → **Yes**

---

### 3. Create Zabbix Database & User
```bash
sudo mysql -u root -p <<EOF
CREATE DATABASE zabbix CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;
CREATE USER 'zabbix'@'localhost' IDENTIFIED BY 'STRONG_PASSWORD_32_CHARS';  # ← CHANGE THIS
GRANT ALL PRIVILEGES ON zabbix.* TO 'zabbix'@'localhost';
FLUSH PRIVILEGES;
EXIT;
EOF
```

> 🔐 **Password Requirements**: Use 32+ character passwords. Never reuse passwords across services.

---

### 4. Add Zabbix Official Repository
```bash
# Download and install Zabbix repository package
wget https://repo.zabbix.com/zabbix/6.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_6.0-4+ubuntu20.04_all.deb
sudo dpkg -i zabbix-release_6.0-4+ubuntu20.04_all.deb
sudo apt update
```

---

### 5. Install Zabbix Components
```bash
sudo apt install -y zabbix-server-mysql zabbix-frontend-php \
  zabbix-apache-conf zabbix-agent zabbix-sql-scripts
```

> ⚠️ **Common Issue**: If `zabbix-sql-scripts` package not found:
> ```bash
> # Fallback: Download SQL scripts manually from source tarball
> cd /tmp
> wget https://cdn.zabbix.com/zabbix/sources/stable/6.0/zabbix-6.0.40.tar.gz
> tar -xzf zabbix-6.0.40.tar.gz
> cd zabbix-6.0.40/database/mysql
> sudo mysql -u root -p zabbix < schema.sql
> sudo mysql -u root -p zabbix < images.sql
> sudo mysql -u root -p zabbix < data.sql
> ```

---

### 6. Import Initial Database Schema
```bash
# Standard method (if zabbix-sql-scripts installed)
zcat /usr/share/doc/zabbix-sql-scripts/mysql/server.sql.gz | \
  sudo mysql -u zabbix -p'zabbix_db_password' zabbix

# Alternative method (if using manual SQL files from Step 5 fallback)
# Already handled in fallback procedure above
```

> ⏱️ **Note**: Schema import takes 1-3 minutes. Do not interrupt.

---

### 7. Configure Zabbix Server (`/etc/zabbix/zabbix_server.conf`)
```ini
# Database settings
DBName=zabbix
DBUser=zabbix
DBPassword=STRONG_PASSWORD_32_CHARS  # ← MUST MATCH STEP 3

# Performance tuning (adjust based on host resources)
StartPollers=10
StartPollersUnreachable=5
StartTrappers=5
StartPingers=3
StartDiscoverers=2
CacheSize=256M
HistoryCacheSize=128M
TrendCacheSize=64M

# Security hardening
LogSlowQueries=3000
Timeout=30
```

---

### 8. Configure PHP for Zabbix Frontend
```bash
# Edit Apache Zabbix configuration
sudo nano /etc/apache2/conf-enabled/zabbix.conf
```

Ensure these settings are present/uncommented:
```apache
<IfModule mod_php7.c>
    php_value max_execution_time 300
    php_value memory_limit 128M
    php_value post_max_size 16M
    php_value upload_max_filesize 2M
    php_value max_input_time 300
    php_value always_populate_raw_post_data -1
    php_value date.timezone Asia/Tehran  # ← SET YOUR TIMEZONE (e.g., UTC, America/New_York)
</IfModule>
```

> 🌐 **Timezone Reference**: Use values from [PHP Supported Timezones](https://www.php.net/manual/en/timezones.php)

---

### 9. Resolve Apache MPM Conflicts (Critical Fix)
> ⚠️ **Common Issue**: PHP not processing → raw PHP code visible in browser

```bash
# Disable conflicting MPM module
sudo a2dismod mpm_event

# Enable required MPM module
sudo a2enmod mpm_prefork

# Enable PHP module
sudo a2enmod php7.4

# Restart Apache
sudo systemctl restart apache2
```

> ✅ **Verification**: `curl -I http://localhost/zabbix` should return `HTTP/1.1 200 OK`, NOT raw PHP code.

---

### 10. Start & Enable Zabbix Services
```bash
# Enable services at boot
sudo systemctl enable zabbix-server zabbix-agent apache2

# Start services
sudo systemctl start zabbix-server zabbix-agent apache2

# Verify status (all should show "active (running)")
sudo systemctl status zabbix-server --no-pager
sudo systemctl status zabbix-agent --no-pager
```

> 📈 **First-start delay**: Zabbix server may take 60-90 seconds to initialize after first start. Check logs:
> ```bash
> journalctl -u zabbix-server -f --since "1 min ago"
> ```

---

### 11. Complete Web Setup
Access in browser: `http://<server-ip>/zabbix`

**Setup Wizard Steps**:
1. **Check prerequisites** → All must show "OK" (fix any failures)
2. **Configure DB connection**:
   - Database type: `MySQL`
   - Host: `localhost`
   - Port: `3306`
   - Database name: `zabbix`
   - User: `zabbix`
   - Password: `STRONG_PASSWORD_32_CHARS`
3. **Zabbix server details**:
   - Host: `localhost`
   - Port: `10051`
   - Name: `Zabbix Server Prod` (optional descriptive name)
4. **Pre-installation summary** → Verify settings → **Next step**
5. **Finish** → Login with default credentials:
   - Username: `Admin`
   - Password: `zabbix`

> 🔐 **Critical Post-Setup Step**:  
> Immediately change default password:
> 1. Click user icon (top right) → **Change password**
> 2. Set strong 20+ character password
> 3. Log out and verify new password works

---

## ✅ Verification Checklist

| Check | Command/Verification |
|-------|----------------------|
| Server running | `systemctl is-active zabbix-server` → `active` |
| Agent running | `systemctl is-active zabbix-agent` → `active` |
| Web UI accessible | `curl -s http://localhost/zabbix | grep -i "zabbix"` → HTML with Zabbix content |
| Database populated | `sudo mysql -u zabbix -p'password' zabbix -e "SELECT COUNT(*) FROM hosts;"` → >0 |
| Agent self-monitored | In UI: `Configuration` → `Hosts` → `Zabbix server` status → **Enabled** (green) |
| Default password changed | Attempt login with `Admin/zabbix` → Should **fail** |

---

## 🛠️ Troubleshooting

| Issue | Solution |
|-------|----------|
| Raw PHP code visible in browser | Fix Apache MPM conflict (Step 9) → `sudo a2dismod mpm_event && sudo a2enmod mpm_prefork php7.4` |
| "Access denied for user 'zabbix'@'localhost'" | Verify password in `/etc/zabbix/zabbix_server.conf` matches MySQL user password |
| Zabbix server won't start | Check logs: `journalctl -u zabbix-server -n 100 --no-pager | grep -i error` |
| Database import fails with "Unknown collation" | Use MySQL 8.0+ or change collation to `utf8mb4_general_ci` in CREATE DATABASE |
| Agent shows "Not available" in UI | Verify firewall: `sudo ufw allow 10050/tcp` and agent config: `ServerActive=localhost` |
| Slow UI performance | Increase PHP memory limit (`php_value memory_limit 256M`) and enable OPcache |

---

## 🔒 Production Hardening Recommendations

| Area | Recommendation |
|------|----------------|
| **Network** | Restrict Zabbix server port (10051) to monitoring subnet only via firewall |
| **Database** | Use dedicated MySQL instance; never share with other applications |
| **Credentials** | Store DB passwords in `/etc/zabbix/zabbix_server.conf` with `chmod 640` + `chown zabbix:zabbix` |
| **Backups** | Daily exports: `mysqldump -u zabbix -p zabbix > /backup/zabbix-$(date +%F).sql` |
| **Updates** | Subscribe to [Zabbix Security Advisories](https://www.zabbix.com/security) |
| **Audit** | Enable Zabbix audit log: `Admin` → `Audit` → Configure retention policy |

---

## 🔗 Related Resources
- [Zabbix 6.0 LTS Official Documentation](https://www.zabbix.com/documentation/6.0)
- [Zabbix Template Repository](https://git.zabbix.com/projects/ZT/repos/zabbix/browse/templates)
- [Zabbix Integration with Prometheus](https://www.zabbix.com/integrations/prometheus)
- [CIS Zabbix Benchmark](https://www.cisecurity.org/cis-benchmarks/)
- [Zabbix Upgrade Path to 7.0 LTS](https://www.zabbix.com/documentation/current/en/manual/installation/upgrade)
