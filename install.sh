#!/usr/bin/env bash
# Instalador de danifreflow-hyprland-dotfiles.
#
# Detecta la distribución, instala los paquetes necesarios y copia los
# dotfiles y el wallpaper. Soportadas: Arch y derivadas (EndeavourOS...),
# Ubuntu 24.04+ y derivadas (Slimbook OS...). En cualquier otra distro se
# pueden copiar solo los dotfiles con --dotfiles-only.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "$REPO_DIR/scripts/common.sh"

usage() {
    cat <<EOF
Uso: ./install.sh [opción]

  (sin opciones)     Instala paquetes y copia los dotfiles
  --dotfiles-only    Solo copia dotfiles y wallpapers (cualquier distro)
  --packages-only    Solo instala paquetes
  -h, --help         Muestra esta ayuda
EOF
}

do_packages=true
do_dotfiles=true
case "${1:-}" in
    "")               ;;
    --dotfiles-only)  do_packages=false ;;
    --packages-only)  do_dotfiles=false ;;
    -h|--help)        usage; exit 0 ;;
    *)                usage; exit 1 ;;
esac

if [[ $EUID -eq 0 ]]; then
    error "No ejecutes este script como root; pedirá sudo cuando lo necesite."
    exit 1
fi

detect_family() {
    # shellcheck disable=SC1091
    . /etc/os-release
    local ids=" ${ID:-} ${ID_LIKE:-} "
    if [[ "$ids" == *" arch "* ]]; then
        echo "arch"
    elif [[ "$ids" == *" ubuntu "* ]]; then
        echo "ubuntu"
    else
        echo "unknown"
    fi
}

if $do_packages; then
    family="$(detect_family)"
    # shellcheck disable=SC1091
    distro_name="$(. /etc/os-release && echo "${PRETTY_NAME:-$ID}")"
    step "Distribución detectada: ${distro_name}"

    case "$family" in
        arch)   source "$REPO_DIR/scripts/arch.sh" ;;
        ubuntu) source "$REPO_DIR/scripts/ubuntu.sh" ;;
        *)
            error "Distribución no soportada para instalar paquetes automáticamente."
            error "Instala Hyprland >= 0.55 y las dependencias del README, y después ejecuta:"
            error "  ./install.sh --dotfiles-only"
            exit 1
            ;;
    esac
    install_packages
fi

if $do_dotfiles; then
    deploy_dotfiles
    install_icon_theme
    verify_hyprland_config
fi

echo
ok "Instalación completada."
info "Cierra sesión y elige 'Hyprland' en la pantalla de inicio de sesión."
info "Ajusta los monitores en ~/.config/hypr/monitors.lua si hace falta."
