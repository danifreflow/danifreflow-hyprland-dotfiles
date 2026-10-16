#!/usr/bin/env bash
# Instalación de paquetes para Ubuntu y derivadas (Slimbook OS, Kubuntu, Pop!_OS, Mint...)
#
# Ubuntu no trae Hyprland (o lo trae muy antiguo, sin soporte para la config
# en Lua), así que se usa la PPA ppa:cppiber/hyprland, que publica las mismas
# versiones que Arch para Ubuntu 24.04 (noble) en adelante.

PPA_OWNER="cppiber"
PPA_NAME="hyprland"
PPA_URL="https://ppa.launchpadcontent.net/${PPA_OWNER}/${PPA_NAME}/ubuntu"
PPA_KEYRING="/etc/apt/keyrings/${PPA_OWNER}-${PPA_NAME}.gpg"
PPA_SOURCES="/etc/apt/sources.list.d/${PPA_OWNER}-${PPA_NAME}.sources"

APT_PACKAGES=(
    # Hyprland y ecosistema (desde la PPA)
    hyprland hyprpaper hypridle hyprlock xdg-desktop-portal-hyprland waybar
    # Aplicaciones
    kitty thunar wofi wlogout mako-notifier zathura pavucontrol
    # Previsualizaciones de Yazi
    ffmpegthumbnailer poppler-utils p7zip-full jq fd-find ripgrep fzf zoxide imagemagick chafa
    # Para compilar dragon (arrastrar archivos desde Yazi)
    build-essential pkg-config libgtk-3-dev
    # Utilidades
    brightnessctl grim slurp wl-clipboard playerctl wlsunset network-manager
    python3 python3-gi gir1.2-playerctl-2.0
    # Tema Qt
    qt6ct qt-style-kvantum
)

# Codename de Ubuntu en el que se basa la distro (Slimbook OS, Mint... tienen el suyo propio)
ubuntu_codename() {
    # shellcheck disable=SC1091
    . /etc/os-release
    echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}"
}

# Añade la PPA a mano (sin add-apt-repository, que falla en algunas derivadas)
add_hyprland_ppa() {
    local codename="$1" fingerprint

    if ! curl -fsI "${PPA_URL}/dists/${codename}/Release" >/dev/null; then
        error "La PPA de Hyprland no tiene paquetes para '${codename}'."
        error "Se necesita Ubuntu 24.04 (noble) o posterior."
        exit 1
    fi
    if [[ "$codename" == "jammy" || "$codename" == "bionic" ]]; then
        warn "En '${codename}' la PPA trae un Hyprland antiguo (< 0.55) sin soporte para Lua;"
        warn "se usará la configuración legacy hyprland.conf. Recomendado: Ubuntu 24.04+."
    fi

    if [[ -f "$PPA_SOURCES" ]]; then
        ok "PPA de Hyprland ya configurada"
        return 0
    fi

    info "Obteniendo la clave de firma de la PPA"
    fingerprint="$(curl -fsSL "https://api.launchpad.net/1.0/~${PPA_OWNER}/+archive/ubuntu/${PPA_NAME}" \
        | python3 -c 'import sys, json; print(json.load(sys.stdin)["signing_key_fingerprint"])')"
    sudo install -d -m 755 /etc/apt/keyrings
    curl -fsSL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x${fingerprint}" \
        | sudo gpg --dearmor --yes -o "$PPA_KEYRING"

    sudo tee "$PPA_SOURCES" >/dev/null <<EOF
Types: deb
URIs: ${PPA_URL}
Suites: ${codename}
Components: main
Signed-By: ${PPA_KEYRING}
EOF
    ok "PPA de Hyprland añadida (${codename})"
}

# Yazi no está en APT: se instala el .deb oficial (versión musl, sin dependencias de glibc)
install_yazi() {
    local arch="$1" tmp
    if command -v yazi &>/dev/null; then
        ok "yazi ya está instalado"
    elif [[ -n "$arch" ]]; then
        tmp="$(mktemp -d)"
        if curl -fsSL "https://github.com/sxyazi/yazi/releases/latest/download/yazi-${arch}-unknown-linux-musl.deb" \
            -o "$tmp/yazi.deb"; then
            sudo apt-get install -y "$tmp/yazi.deb"
            ok "yazi instalado"
        else
            warn "No se pudo descargar yazi"
        fi
        rm -rf "$tmp"
    fi
    # En Ubuntu el binario de fd se llama fdfind; Yazi busca `fd`
    if ! command -v fd &>/dev/null && command -v fdfind &>/dev/null; then
        sudo ln -sf "$(command -v fdfind)" /usr/local/bin/fd
    fi
}

# dragon no está en APT ni publica binarios: se compila (es un único archivo C).
# Se instala como `dragon-drop`, el mismo nombre que usa el paquete de Arch.
install_dragon() {
    local tmp
    if command -v dragon-drop &>/dev/null; then
        ok "dragon-drop ya está instalado"
        return 0
    fi
    tmp="$(mktemp -d)"
    if curl -fsSL "https://github.com/mwh/dragon/archive/master.tar.gz" | tar -xz -C "$tmp"; then
        make -C "$tmp/dragon-master" NAME=dragon-drop >/dev/null
        sudo make -C "$tmp/dragon-master" NAME=dragon-drop PREFIX=/usr/local install >/dev/null
        ok "dragon-drop instalado"
    else
        warn "No se pudo descargar dragon"
    fi
    rm -rf "$tmp"
}

install_packages() {
    local codename
    codename="$(ubuntu_codename)"
    info "Base Ubuntu detectada: ${codename}"

    step "Instalando dependencias básicas"
    sudo apt-get update
    sudo apt-get install -y curl gpg ca-certificates python3 unzip fontconfig

    step "Configurando la PPA de Hyprland"
    add_hyprland_ppa "$codename"

    step "Instalando paquetes"
    sudo apt-get update
    sudo apt-get install -y "${APT_PACKAGES[@]}"

    step "Instalando herramientas que no están en APT"
    local arch
    arch="$(gh_arch)"
    if [[ -n "$arch" ]]; then
        install_github_binary bzmenu \
            "https://github.com/e-tho/bzmenu/releases/latest/download/bzmenu-${arch}-linux-gnu"
    else
        warn "Arquitectura $(uname -m) no soportada para bzmenu"
    fi
    if [[ "$arch" == "x86_64" ]]; then
        install_github_binary wttrbar \
            "https://github.com/bjesus/wttrbar/releases/latest/download/wttrbar"
    else
        warn "wttrbar solo publica binario para x86_64; compílalo desde https://github.com/bjesus/wttrbar"
    fi

    install_yazi "$arch"
    install_dragon

    step "Instalando Nerd Fonts"
    install_nerd_font JetBrainsMono
    install_nerd_font Inconsolata
}
