#!/usr/bin/env bash
# Funciones compartidas por todos los instaladores.
# Se carga con `source`; espera que REPO_DIR esté definido.

GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
BLUE='\033[1;34m'
NC='\033[0m'

info()  { echo -e "${YELLOW}[+]${NC} $*"; }
ok()    { echo -e "${GREEN}[✔]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
error() { echo -e "${RED}[✘]${NC} $*" >&2; }
step()  { echo -e "\n${BLUE}==>${NC} $*"; }

# Directorios de ~/.config que gestiona este repo
CONFIG_DIRS=(hypr kitty Kvantum mako Thunar waybar wlogout wofi xfce4 yazi zathura)

# Archivos que dependen de cada máquina: si ya existen, no se sobrescriben
PRESERVE_FILES=(hypr/monitors.lua)

# Arquitectura en el formato que usan los binarios de GitHub
gh_arch() {
    case "$(uname -m)" in
        x86_64)  echo "x86_64" ;;
        aarch64) echo "aarch64" ;;
        *)       echo "" ;;
    esac
}

# Descarga un binario precompilado de un release de GitHub a /usr/local/bin
#   install_github_binary <nombre> <url>
install_github_binary() {
    local name="$1" url="$2" tmp
    if command -v "$name" &>/dev/null; then
        ok "$name ya está instalado"
        return 0
    fi
    tmp="$(mktemp)"
    if curl -fsSL "$url" -o "$tmp"; then
        sudo install -m 755 "$tmp" "/usr/local/bin/$name"
        ok "$name instalado en /usr/local/bin"
    else
        warn "No se pudo descargar $name desde $url"
    fi
    rm -f "$tmp"
}

# Instala una Nerd Font desde el release oficial en ~/.local/share/fonts
#   install_nerd_font <Nombre>   (p.ej. JetBrainsMono)
install_nerd_font() {
    local font="$1"
    local dest="$HOME/.local/share/fonts/NerdFonts/$font"
    if grep -qi "${font} Nerd Font" <<<"$(fc-list 2>/dev/null)"; then
        ok "$font Nerd Font ya está instalada"
        return 0
    fi
    local tmp
    tmp="$(mktemp -d)"
    if curl -fsSL "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/${font}.zip" -o "$tmp/font.zip"; then
        mkdir -p "$dest"
        unzip -oq "$tmp/font.zip" -d "$dest"
        ok "$font Nerd Font instalada"
    else
        warn "No se pudo descargar $font Nerd Font"
    fi
    rm -rf "$tmp"
}

is_preserved() {
    local rel="$1" p
    for p in "${PRESERVE_FILES[@]}"; do
        [[ "$rel" == "$p" ]] && return 0
    done
    return 1
}

# Copia los dotfiles a ~/.config haciendo backup de lo que ya hubiera
deploy_dotfiles() {
    local backup_dir="$HOME/.config-backup/$(date +%Y%m%d-%H%M%S)"
    local dir rel src dst

    step "Copiando dotfiles a ~/.config"
    for dir in "${CONFIG_DIRS[@]}"; do
        if [[ -d "$HOME/.config/$dir" ]]; then
            mkdir -p "$backup_dir"
            cp -a "$HOME/.config/$dir" "$backup_dir/"
        fi

        while IFS= read -r -d '' src; do
            rel="${src#"$REPO_DIR/.config/"}"
            dst="$HOME/.config/$rel"
            if is_preserved "$rel" && [[ -e "$dst" ]]; then
                warn "Conservando $dst (configuración propia de esta máquina)"
                continue
            fi
            mkdir -p "$(dirname "$dst")"
            cp "$src" "$dst"
        done < <(find "$REPO_DIR/.config/$dir" -type f -print0)
        ok "$dir"
    done
    if [[ -d "$backup_dir" ]]; then
        info "Backup de la configuración anterior en $backup_dir"
    fi

    # Algunos archivos llevan rutas absolutas del usuario original
    if [[ "$HOME" != "/home/dani" ]]; then
        grep -rlZ "/home/dani" "${CONFIG_DIRS[@]/#/$HOME/.config/}" 2>/dev/null \
            | xargs -0 -r sed -i "s|/home/dani|$HOME|g"
    fi

    chmod +x "$HOME/.config/waybar/modules/"* 2>/dev/null || true

    step "Copiando wallpapers a ~/wallpapers"
    mkdir -p "$HOME/wallpapers"
    cp -r "$REPO_DIR/wallpapers/." "$HOME/wallpapers/"
    ok "Wallpapers copiados"

    # Carpeta donde se guardan las capturas (tecla Print)
    mkdir -p "$HOME/capturas"

    if command -v fc-cache &>/dev/null; then
        fc-cache -f >/dev/null
    fi
}

# Tema de iconos: Papirus-Dark con carpetas Catppuccin Mocha (mauve).
# Se instala en ~/.local/share/icons para no depender de paquetes de la distro.
ICON_THEME="Papirus-Dark"
FOLDER_COLOR="cat-mocha-mauve"

install_icon_theme() {
    local icons="$HOME/.local/share/icons" tmp
    step "Instalando iconos Papirus-Dark con carpetas Catppuccin"

    tmp="$(mktemp -d)"
    if [[ ! -d "$icons/Papirus-Dark" ]]; then
        if curl -fsSL "https://github.com/PapirusDevelopmentTeam/papirus-icon-theme/archive/master.tar.gz" \
            | tar -xz -C "$tmp"; then
            mkdir -p "$icons"
            cp -R "$tmp/papirus-icon-theme-master/Papirus" "$tmp/papirus-icon-theme-master/Papirus-Dark" "$icons/"
            ok "Papirus instalado en $icons"
        else
            warn "No se pudo descargar Papirus"
            rm -rf "$tmp"
            return 0
        fi
    else
        ok "Papirus ya está instalado"
    fi

    if curl -fsSL "https://github.com/catppuccin/papirus-folders/archive/main.tar.gz" | tar -xz -C "$tmp" \
        && curl -fsSL "https://raw.githubusercontent.com/PapirusDevelopmentTeam/papirus-folders/master/papirus-folders" \
            -o "$tmp/papirus-folders"; then
        cp -R "$tmp/papirus-folders-main/src/." "$icons/Papirus/"
        chmod +x "$tmp/papirus-folders"
        USER_HOME="$HOME" "$tmp/papirus-folders" -C "$FOLDER_COLOR" --theme "$ICON_THEME" >/dev/null
        ok "Carpetas en color $FOLDER_COLOR"
    else
        warn "No se pudieron aplicar los colores Catppuccin a las carpetas"
    fi
    rm -rf "$tmp"

    # Activar el tema para las aplicaciones GTK (Thunar...)
    if command -v gsettings &>/dev/null; then
        gsettings set org.gnome.desktop.interface icon-theme "$ICON_THEME" 2>/dev/null || true
    fi
    local ini
    for ini in "$HOME/.config/gtk-3.0/settings.ini" "$HOME/.config/gtk-4.0/settings.ini"; do
        mkdir -p "$(dirname "$ini")"
        if [[ ! -f "$ini" ]]; then
            printf '[Settings]\ngtk-icon-theme-name=%s\n' "$ICON_THEME" >"$ini"
        elif grep -q '^gtk-icon-theme-name=' "$ini"; then
            sed -i "s/^gtk-icon-theme-name=.*/gtk-icon-theme-name=$ICON_THEME/" "$ini"
        else
            sed -i "/^\[Settings\]/a gtk-icon-theme-name=$ICON_THEME" "$ini"
        fi
    done
    ok "Tema de iconos activado: $ICON_THEME"
}

# Comprueba que la configuración de Hyprland es válida
verify_hyprland_config() {
    step "Verificando la configuración de Hyprland"
    if ! command -v Hyprland &>/dev/null; then
        warn "Hyprland no está instalado; no se puede verificar la configuración"
        return 0
    fi
    # La config en Lua necesita Hyprland >= 0.55; antes se usa hyprland.conf
    local version major minor config out
    version="$(Hyprland --version 2>/dev/null | awk 'NR==1{print $2}')"
    IFS=. read -r major minor _ <<<"$version"
    if (( major == 0 && minor < 55 )); then
        warn "Hyprland $version no soporta la configuración en Lua; se usará hyprland.conf (legacy)."
        config="$HOME/.config/hypr/hyprland.conf"
    else
        config="$HOME/.config/hypr/hyprland.lua"
    fi

    out="$(Hyprland --verify-config -c "$config" 2>&1 | sed -n '/Config parsing result/,$p' || true)"
    if grep -q "config ok" <<<"$out"; then
        ok "Configuración de Hyprland válida ($(basename "$config"), Hyprland $version)"
    else
        warn "La configuración de Hyprland tiene errores:"
        echo "$out"
    fi
}
