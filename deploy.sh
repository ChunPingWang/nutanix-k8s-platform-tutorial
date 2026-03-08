#!/bin/bash
#
# NKP PoC 方案 B - 一鍵部署腳本
# 使用方式:
#   ./deploy.sh              # 完整部署
#   ./deploy.sh --phase vm   # 僅建立 VM
#   ./deploy.sh --phase base # 僅基礎配置
#   ./deploy.sh --phase k8s  # 僅部署 K8s
#   ./deploy.sh --phase cni  # 僅安裝 CNI
#   ./deploy.sh --phase platform # 僅安裝平台元件
#   ./deploy.sh --phase verify   # 僅驗證
#   ./deploy.sh --destroy    # 銷毀所有 VM
#
set -euo pipefail

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日誌函數
log_info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
log_ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# 專案根目錄
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
INVENTORY="${PROJECT_DIR}/inventory/hosts.yml"
KUBECONFIG_DIR="${PROJECT_DIR}/kubeconfig"

# 檢查前置工具
check_prerequisites() {
    log_info "檢查前置工具..."
    local missing=()

    command -v vagrant  >/dev/null 2>&1 || missing+=("vagrant")
    command -v ansible  >/dev/null 2>&1 || missing+=("ansible")
    command -v vboxmanage >/dev/null 2>&1 || missing+=("virtualbox")

    if [ ${#missing[@]} -gt 0 ]; then
        log_error "缺少以下工具: ${missing[*]}"
        log_info "請執行: sudo apt install -y ${missing[*]}"
        exit 1
    fi

    # 檢查 CPU 虛擬化支援
    if ! grep -qE 'vmx|svm' /proc/cpuinfo 2>/dev/null; then
        log_warn "未偵測到 CPU 虛擬化支援 (VT-x/AMD-V)，VirtualBox 可能無法正常運作"
    fi

    log_ok "前置工具檢查通過"
}

# Phase 1: 建立 VM
phase_vm() {
    log_info "=== Phase 1: 建立 VirtualBox VM ==="
    cd "$PROJECT_DIR"
    vagrant up
    log_ok "所有 VM 已建立完成"
    vagrant status
}

# Phase 2: 基礎 OS 配置
phase_base() {
    log_info "=== Phase 2: 基礎 OS 配置 ==="
    ansible-playbook -i "$INVENTORY" "${PROJECT_DIR}/playbooks/base-setup.yml"
    log_ok "基礎配置完成"
}

# Phase 3: 部署 K8s Cluster
phase_k8s() {
    log_info "=== Phase 3: 部署 Kubernetes Cluster ==="
    mkdir -p "$KUBECONFIG_DIR"
    ansible-playbook -i "$INVENTORY" "${PROJECT_DIR}/playbooks/kubeadm-init.yml"
    log_ok "Kubernetes 叢集部署完成"
    log_info "Kubeconfig 已儲存至: ${KUBECONFIG_DIR}/"
}

# Phase 4: 安裝 CNI
phase_cni() {
    log_info "=== Phase 4: 安裝 Cilium CNI ==="
    ansible-playbook -i "$INVENTORY" "${PROJECT_DIR}/playbooks/install-cilium.yml"
    log_ok "Cilium CNI 安裝完成"
}

# Phase 5: 安裝平台元件
phase_platform() {
    log_info "=== Phase 5: 安裝平台元件 ==="
    ansible-playbook -i "$INVENTORY" "${PROJECT_DIR}/playbooks/install-platform-stack.yml"
    log_ok "平台元件安裝完成"
}

# Phase 6: 驗證
phase_verify() {
    log_info "=== Phase 6: 全面驗證 ==="
    ansible-playbook -i "$INVENTORY" "${PROJECT_DIR}/playbooks/verify-all.yml"
    log_ok "驗證完成"
}

# 銷毀所有 VM
destroy() {
    log_warn "即將銷毀所有 VM！"
    read -rp "確認銷毀？(y/N): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        cd "$PROJECT_DIR"
        vagrant destroy -f
        rm -rf "$KUBECONFIG_DIR"
        log_ok "所有 VM 已銷毀"
    else
        log_info "取消銷毀"
    fi
}

# 顯示使用說明
usage() {
    echo "NKP PoC 方案 B - 部署腳本"
    echo ""
    echo "使用方式:"
    echo "  $0                    完整部署（Phase 1-6）"
    echo "  $0 --phase <phase>    執行指定 Phase"
    echo "  $0 --destroy          銷毀所有 VM"
    echo "  $0 --help             顯示此說明"
    echo ""
    echo "可用 Phase:"
    echo "  vm        Phase 1: 建立 VirtualBox VM"
    echo "  base      Phase 2: 基礎 OS 配置"
    echo "  k8s       Phase 3: 部署 Kubernetes Cluster"
    echo "  cni       Phase 4: 安裝 Cilium CNI"
    echo "  platform  Phase 5: 安裝平台元件"
    echo "  verify    Phase 6: 全面驗證"
}

# 主程式
main() {
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║   NKP PoC 方案 B：開源等效元件模擬 NKP 功能棧         ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo ""

    case "${1:-all}" in
        --phase)
            check_prerequisites
            case "${2:-}" in
                vm)       phase_vm ;;
                base)     phase_base ;;
                k8s)      phase_k8s ;;
                cni)      phase_cni ;;
                platform) phase_platform ;;
                verify)   phase_verify ;;
                *)        log_error "未知 phase: ${2:-}"; usage; exit 1 ;;
            esac
            ;;
        --destroy)
            destroy
            ;;
        --help|-h)
            usage
            ;;
        all)
            check_prerequisites
            phase_vm
            phase_base
            phase_k8s
            phase_cni
            phase_platform
            phase_verify
            echo ""
            log_ok "=== 全部部署完成！==="
            log_info "使用 'export KUBECONFIG=${KUBECONFIG_DIR}/mgmt-cluster.conf' 連接 Management Cluster"
            log_info "使用 'export KUBECONFIG=${KUBECONFIG_DIR}/workload-cluster.conf' 連接 Workload Cluster"
            ;;
        *)
            usage
            exit 1
            ;;
    esac
}

main "$@"
