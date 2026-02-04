# 🪣 MinIO CE Installation & Benchmarking Guide | Object Storage for DevOps

> **High-Performance S3-Compatible Object Storage**  
> Production-ready MinIO Community Edition setup with security hardening, multi-tool benchmarking (Warp, mc, FIO), SDK integration, and observability via Prometheus/Grafana. Ideal for Kubernetes persistent storage, backup targets, and cloud-native data lakes.

---

## 📋 Prerequisites

| Requirement | Specification | Verification Command |
|-------------|---------------|----------------------|
| OS | Ubuntu 22.04 LTS / RHEL 8+ | `lsb_release -a` |
| Architecture | x86_64 or ARM64 | `uname -m` |
| Disk Space | 10 GB+ per node (SSD recommended) | `df -h /opt` |
| RAM | 4 GB minimum (8 GB+ for production) | `free -h` |
| Network | Dedicated storage network (1 GbE+) | `ip addr show` |

> ⚠️ **Critical Security Note**: MinIO defaults to `minioadmin:minioadmin` credentials. **Always change these before exposing to networks**.

---

## 🔧 Installation Steps

### 1. Create Dedicated Service User & Storage Directory
```bash
# Create non-root service account
sudo useradd -r -s /usr/sbin/nologin minio-user

# Create storage directory with proper permissions
sudo mkdir -p /opt/minio/data
sudo chown -R minio-user:minio-user /opt/minio/data
sudo chmod 700 /opt/minio/data
```

### 2. Download & Install MinIO Server
```bash
# Download latest MinIO server binary
wget https://dl.min.io/server/minio/release/linux-amd64/minio

# Set executable permissions (current user only)
chmod u+x minio

# Move to standard location
sudo mv minio /usr/local/bin/

# Verify installation
minio --version  # Expected: RELEASE.2025-07-23T15-54-02Z
```

### 3. Configure Environment Variables (Security Hardening)
```bash
# Create environment file for systemd
sudo tee /etc/default/minio <<'EOF'
# MinIO root credentials (CHANGE THESE!)
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=STRONG_PASSWORD_32_CHARS  # ← MUST CHANGE

# Storage path
MINIO_VOLUMES="/opt/minio/data"

# Network binding (0.0.0.0 = all interfaces, specify IP for production)
MINIO_ADDRESS=":9000"
MINIO_CONSOLE_ADDRESS=":9001"

# Enable bucket notification targets (optional)
MINIO_NOTIFY_WEBHOOK_ENABLE_1="on"
EOF

# Restrict permissions
sudo chmod 600 /etc/default/minio
sudo chown root:root /etc/default/minio
```

> 🔐 **Password Requirements**: Use 32+ character passwords generated via `openssl rand -base64 32`. Never commit credentials to version control.

---

### 4. Create Systemd Service (`/etc/systemd/system/minio.service`)
```ini
[Unit]
Description=MinIO Object Storage Server
Documentation=https://min.io/docs/minio/linux/index.html
After=network-online.target
Wants=network-online.target

[Service]
Type=notify
User=minio-user
Group=minio-user
EnvironmentFile=/etc/default/minio
ExecStartPre=/bin/bash -c "if [ -z \"${MINIO_ROOT_USER}\" ] || [ -z \"${MINIO_ROOT_PASSWORD}\" ]; then echo 'MinIO credentials not set in /etc/default/minio'; exit 1; fi"
ExecStart=/usr/local/bin/minio server $MINIO_VOLUMES
Restart=always
RestartSec=10
LimitNOFILE=1048576
LimitNPROC=512
TimeoutStopSec=0
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
```

> ✅ **Hardening Applied**:
> - Dedicated service user (`minio-user`)
> - Credential validation before startup (`ExecStartPre`)
> - Resource limits (`LimitNOFILE`, `LimitNPROC`)
> - Filesystem isolation (`PrivateTmp`, `ProtectSystem`)
> - Privilege dropping (`NoNewPrivileges`)

---

### 5. Start MinIO Service
```bash
# Reload systemd and start service
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable --now minio

# Verify service status
sudo systemctl status minio
journalctl -u minio -f --since "1 min ago"  # Monitor logs
```

---

### 6. Access MinIO Console
```
Web UI:    http://<server-ip>:9001
API Endpoint: http://<server-ip>:9000
Default Credentials (IF NOT CHANGED): minioadmin / minioadmin
```

> 🔐 **First-login security checklist**:
> - [ ] Change root credentials immediately via UI (`Settings` → `Accounts`)
> - [ ] Create service accounts with least-privilege policies
> - [ ] Enable bucket versioning for critical data
> - [ ] Configure TLS certificates (self-signed not recommended for production)
> - [ ] Set up bucket lifecycle policies for automatic cleanup
> - [ ] Enable audit logging to SIEM/Splunk

---

## 🧪 Benchmarking Methodologies

### Method 1: Warp (Official MinIO Benchmark Tool)
```bash
# Download Warp
wget https://github.com/minio/warp/releases/latest/download/warp-linux-amd64
chmod +x warp-linux-amd64
sudo mv warp-linux-amd64 /usr/local/bin/warp

# Run multi-client PUT benchmark (10 clients, 1000 objects @ 100MB each)
warp mixed --host http://<minio-ip>:9000 \
  --access-key minioadmin \
  --secret-key STRONG_PASSWORD \
  --bucket benchmark-bucket \
  --objects 1000 \
  --obj.size 100MB \
  --concurrent 10
```

### Method 2: MinIO Client (`mc`) Operations
```bash
# Install MinIO Client on benchmark machine
wget https://dl.min.io/client/mc/release/linux-amd64/mc
chmod +x mc
sudo mv mc /usr/local/bin/

# Configure alias
mc alias set myminio http://<minio-ip>:9000 minioadmin STRONG_PASSWORD

# Upload entire directory (measures throughput)
time mc cp --recursive /path/to/large-dataset myminio/benchmark-bucket/

# Download test (measures read throughput)
time mc cp --recursive myminio/benchmark-bucket/ /tmp/download-test/
```

### Method 3: FIO for Disk I/O Validation
```bash
# Install FIO
sudo apt install -y fio

# Test raw disk performance (validate storage backend)
fio --name=randwrite --ioengine=libaio --rw=randwrite \
  --bs=4k --numjobs=4 --size=4G --runtime=60 \
  --directory=/opt/minio/data --group_reporting
```

### Method 4: Prometheus + Grafana Observability
```yaml
# prometheus.yml snippet
scrape_configs:
  - job_name: 'minio'
    metrics_path: '/minio/v2/metrics/cluster'
    static_configs:
      - targets: ['<minio-ip>:9000']
    basic_auth:
      username: 'minioadmin'
      password: 'STRONG_PASSWORD'
```

> 📊 **Key Metrics to Monitor**:
> - `s3_tx_bytes_total` / `s3_rx_bytes_total` → Throughput
> - `disk_storage_available` → Capacity planning
> - `s3_errors_total` → Error rate analysis
> - `bucket_objects_count` → Growth trends

---

## 💻 SDK Integration Example (Python)

```python
from minio import Minio
from minio.error import S3Error

# Initialize client (NEVER hardcode credentials in production - use env vars/secrets manager)
client = Minio(
    "<minio-server>:9000",
    access_key="minioadmin",
    secret_key="STRONG_PASSWORD",
    secure=False  # Set to True with valid TLS certificates
)

bucket_name = "devops-backups"

# Create bucket if missing
if not client.bucket_exists(bucket_name):
    client.make_bucket(bucket_name)
    print(f"Created bucket: {bucket_name}")

# Upload file with metadata
client.fput_object(
    bucket_name,
    "backup-20250205.tar.gz",
    "./backup.tar.gz",
    content_type="application/gzip",
    metadata={"environment": "production", "retention": "90d"}
)
print("File uploaded successfully!")

# List objects with prefix filtering
for obj in client.list_objects(bucket_name, prefix="backup-"):
    print(f"{obj.object_name} | Size: {obj.size} bytes | Last Modified: {obj.last_modified}")
```

> 🔒 **Production Security Practices**:
> - Store credentials in HashiCorp Vault/AWS Secrets Manager
> - Use IAM policies to restrict bucket access per service account
> - Enable bucket encryption at rest (`mc encrypt set sse-s3 myminio/bucket`)
> - Implement bucket policies for least-privilege access

---

## ✅ Verification Checklist

| Check | Command/Verification |
|-------|----------------------|
| Service running | `systemctl is-active minio` → `active` |
| Listening on ports | `ss -tulpn \| grep -E ':(9000|9001)'` → `LISTEN` |
| Storage writable | `sudo -u minio-user touch /opt/minio/data/.test && rm /opt/minio/data/.test` |
| API accessible | `curl -I http://localhost:9000/minio/health/live` → `HTTP/1.1 200 OK` |
| Console accessible | Open `http://<ip>:9001` in browser → Login screen |
| Default creds changed | `grep -q "minioadmin" /etc/default/minio && echo "VULNERABLE"` → Should return nothing |

---

## 🛠️ Troubleshooting

| Issue | Solution |
|-------|----------|
| `file access denied` on storage path | `sudo chown -R minio-user:minio-user /opt/minio/data && sudo chmod 700 /opt/minio/data` |
| Service fails to start | Check logs: `journalctl -u minio -n 100 --no-pager \| grep -i error` |
| Connection refused on 9000/9001 | Verify firewall: `sudo ufw allow 9000:9001/tcp` |
| Slow upload/download speeds | Check disk I/O (`iostat -x 2`), network latency (`mtr <client-ip>`), and MTU settings |
| Bucket creation fails | Verify quota policies: `mc admin bucket quota myminio/bucket-name` |

---

## 🔗 Related Resources
- [MinIO Official Documentation](https://min.io/docs/minio/linux/index.html)
- [MinIO Kubernetes Operator](https://min.io/docs/minio/kubernetes/upstream/index.html)
- [S3 Compatibility Testing](https://github.com/minio/s3verify)
- [Production Hardening Guide](https://min.io/docs/minio/linux/operations/security/hardening-guide.html)
- [Benchmarking Best Practices](https://min.io/docs/minio/linux/performance/benchmarks.html)
- [MinIO vs AWS S3 Feature Comparison](https://min.io/docs/minio/linux/integrations/aws-s3-comparison.html)
