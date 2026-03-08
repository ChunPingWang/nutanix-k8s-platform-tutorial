# NKP PoC 方案 B：開源等效元件模擬 NKP 功能棧

> **目標**：使用 NKP 底層的開源元件，在 Ubuntu + VirtualBox 環境自行組裝一個功能等效的平台
> **涵蓋 NKP 功能**：~60%
> **成本**：免費
> **適用場景**：驗證 NKP 底層技術棧概念、培訓團隊 Cloud Native 技能

## 架構概覽

```
Ubuntu Host
├── VirtualBox
│   ├── VM-1: Management Cluster (kubeadm)
│   │   ├── Prometheus + Grafana + Thanos
│   │   ├── Harbor Registry
│   │   ├── Flux CD (GitOps)
│   │   ├── Dex (SSO) + Cert-Manager
│   │   └── Velero (Backup/DR)
│   │
│   ├── VM-2: Workload Cluster A (kubeadm)
│   │   ├── Cilium CNI + Hubble UI
│   │   ├── Traefik Ingress
│   │   ├── Trivy + Polaris + Gatekeeper
│   │   ├── Fluent Bit → Loki
│   │   └── Application Workloads
│   │
│   └── VM-3: Workload Cluster B (輕量)
│
├── Vagrant (VM 自動化)
├── Ansible (配置管理)
└── Helm / Kustomize (應用部署)
```

## NKP 元件對照表

| NKP 功能 | NKP 使用的元件 | 本地替代方案 |
|---------|-------------|-----------|
| K8s Runtime | Upstream K8s | kubeadm |
| CNI / 零信任網路 | Cilium | Cilium |
| Ingress | Traefik | Traefik |
| 弱點掃描 | Trivy | Trivy |
| 配置合規 | Polaris | Polaris |
| 策略引擎 | OPA Gatekeeper | OPA Gatekeeper |
| 監控 | Prometheus + Grafana | kube-prometheus-stack |
| 長期指標 | Thanos | Thanos |
| 日誌 | Fluent Bit | Fluent Bit + Loki |
| GitOps | Flux CD | Flux CD |
| 成本管理 | Kubecost | OpenCost |
| Image Registry | Harbor | Harbor |
| 憑證管理 | Cert-Manager | Cert-Manager |
| SSO | Dex | Dex |
| Dashboard | Kommander | Kubernetes Dashboard |
| DR/Backup | Velero | Velero |

## 硬體最低需求

| 資源 | 最低需求 | 建議配置 |
|------|---------|---------|
| CPU | 8 cores | 16+ cores |
| RAM | 32 GB | 64+ GB |
| Disk | 200 GB SSD | 500 GB NVMe |

## 快速開始

### 前置安裝

```bash
# 安裝工具鏈
sudo apt update && sudo apt install -y virtualbox vagrant ansible python3-pip
pip3 install jmespath  # Ansible JSON 處理

# 驗證安裝
vagrant --version
ansible --version
vboxmanage --version
```

### 一鍵部署

```bash
# 複製專案
git clone <repo-url> && cd nutanix-k8s-platform-tutorial

# 一鍵部署全部
./deploy.sh

# 或分階段執行
./deploy.sh --phase vm        # Phase 1: 建立 VM
./deploy.sh --phase base      # Phase 2: 基礎配置
./deploy.sh --phase k8s       # Phase 3: 部署 K8s
./deploy.sh --phase cni       # Phase 4: 安裝 Cilium CNI
./deploy.sh --phase platform  # Phase 5: 安裝平台元件
./deploy.sh --phase verify    # Phase 6: 驗證
```

### 存取服務

部署完成後，各服務的預設存取方式：

| 服務 | URL | 預設帳密 |
|------|-----|---------|
| Grafana | https://grafana.192.168.56.10.nip.io | admin / prom-operator |
| Traefik Dashboard | https://traefik.192.168.56.10.nip.io | N/A |
| Harbor | https://harbor.192.168.56.10.nip.io | admin / Harbor12345 |
| Hubble UI | https://hubble.192.168.56.10.nip.io | N/A |
| Polaris | https://polaris.192.168.56.10.nip.io | N/A |
| K8s Dashboard | https://dashboard.192.168.56.10.nip.io | Token-based |

### 清理環境

```bash
# 銷毀所有 VM
vagrant destroy -f

# 清理本地暫存
rm -rf .vagrant/ *.retry
```

## 目錄結構

```
.
├── README.md
├── Vagrantfile                          # VM 定義
├── deploy.sh                            # 主控部署腳本
├── inventory/
│   └── hosts.yml                        # Ansible inventory
├── playbooks/
│   ├── base-setup.yml                   # OS 基礎配置
│   ├── kubeadm-init.yml                 # kubeadm 叢集初始化
│   ├── kubeadm-join.yml                 # Worker 加入叢集
│   ├── install-cilium.yml               # Cilium CNI
│   ├── install-platform-stack.yml       # 平台元件總安裝
│   ├── install-monitoring.yml           # Prometheus + Grafana + Loki
│   ├── install-security.yml             # Gatekeeper + Trivy + Polaris
│   ├── install-ingress.yml              # Traefik + Cert-Manager
│   ├── install-gitops.yml               # Flux CD
│   ├── install-registry.yml             # Harbor
│   ├── install-backup.yml               # Velero + MinIO
│   └── verify-all.yml                   # 全面驗證
├── roles/
│   └── common/
│       └── tasks/
│           └── main.yml                 # 共用 OS 配置 tasks
├── helm-values/
│   ├── cilium-values.yaml               # Cilium Helm values
│   ├── prometheus-values.yaml           # kube-prometheus-stack values
│   ├── loki-values.yaml                 # Loki Stack values
│   ├── traefik-values.yaml              # Traefik values
│   ├── cert-manager-values.yaml         # Cert-Manager values
│   ├── gatekeeper-values.yaml           # Gatekeeper values
│   ├── trivy-values.yaml                # Trivy Operator values
│   ├── polaris-values.yaml              # Polaris values
│   ├── harbor-values.yaml               # Harbor values
│   └── velero-values.yaml               # Velero values
├── manifests/
│   ├── metallb-config.yaml              # MetalLB IP Pool
│   ├── gatekeeper-policies/             # OPA 策略
│   │   ├── require-labels.yaml
│   │   ├── block-privileged.yaml
│   │   └── require-resource-limits.yaml
│   └── sample-app/                      # 範例應用
│       ├── namespace.yaml
│       ├── deployment.yaml
│       ├── service.yaml
│       └── ingress.yaml
└── docs/
    └── comparison-report-template.md    # NKP vs 開源 比較報告模板
```

## 方案限制

| 限制項目 | 影響 | Workaround |
|---------|------|------------|
| 無 Kommander Dashboard | 缺少統一管理 UI | 使用 Kubernetes Dashboard |
| 無 NKP Insights / AI Navigator | 缺少 AI 輔助功能 | 無替代品 |
| 無 Nutanix CSI | 無法測試 Nutanix 原生儲存 | 使用 local-path provisioner |
| 無 Fleet Management | 無法測試多叢集統一管理 | 使用 CAPI + ArgoCD 模擬 |
| 巢狀虛擬化效能差 | 效能測試不具參考性 | 僅做功能驗證 |

## License

本專案僅供學習與 PoC 驗證用途。各開源元件遵循其各自的授權條款。
