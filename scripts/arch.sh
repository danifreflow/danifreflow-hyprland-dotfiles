#!/usr/bin/env bash
# Instalación de paquetes para Arch Linux y derivadas (EndeavourOS, Manjaro, CachyOS...)

PACMAN_PACKAGES=(
    # Hyprland y ecosistema
    hyprland hyprpaper hypridle hyprlock xdg-desktop-portal-hyprland
    # Aplicaciones
    kitty thunar wofi waybar mako zathura zathura-pdf-mupdf pavucontrol
    # Yazi (gestor de archivos en terminal) y sus previsualizaciones
    yazi ffmpegthumbnailer poppler 7zip jq fd ripgrep fzf zoxide imagemagick resvg chafa
    # Utilidades
    brightnessctl grim slurp wl-clipboard playerctl wlsunset networkmanager
    python python-gobject
    # Tema Qt
    qt6ct kvantum
    # Fuentes
    ttf-jetbrains-mono-nerd ttf-inconsolata-nerd
)

AUR_PACKAGES=(wlogout bzmenu wttrbar dragon-drop)

install_packages() {
    step "Instalando paquetes de los repositorios oficiales"
    sudo pacman -S --needed --noconfirm "${PACMAN_PACKAGES[@]}"

    step "Instalando paquetes de AUR"
    if ! command -v yay &>/dev/null && ! command -v paru &>/dev/null; then
        info "No hay helper de AUR; instalando yay"
        sudo pacman -S --needed --noconfirm git base-devel
        local tmp
        tmp="$(mktemp -d)"
        git clone https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
        (cd "$tmp/yay-bin" && makepkg -si --noconfirm)
        rm -rf "$tmp"
    fi
    local aur_helper
    aur_helper="$(command -v paru || command -v yay)"
    "$aur_helper" -S --needed --noconfirm "${AUR_PACKAGES[@]}"
}
