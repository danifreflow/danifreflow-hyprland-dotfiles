#!/bin/bash
set -e

# --------- COLORES ---------
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}[+] Comprobando yay...${NC}"
if ! command -v yay &> /dev/null; then
  echo -e "${YELLOW}[!] yay no encontrado. Instalando...${NC}"
  sudo pacman -S --needed git base-devel
  git clone https://aur.archlinux.org/yay.git
  cd yay && makepkg -si && cd ..
fi

# --------- PAQUETES NECESARIOS ---------
echo -e "${YELLOW}[+] Instalando paquetes necesarios...${NC}"
yay -S --needed --noconfirm \
  hyprland hyprpaper hypridle hyprlock \
  kitty thunar wofi waybar wlogout mako \
  brightnessctl grim slurp wl-clipboard \
  xdg-desktop-portal-hyprland nerd-fonts 
# --------- COPIAR DOTFILES ---------
CONFIG_FILES=(hypr kitty Kvantum mako Thunar waybar wlogout wofi xfce4 zathura)
echo -e "${YELLOW}[+] Copiando dotfiles a ~/.config...${NC}"

for dir in "${CONFIG_FILES[@]}"; do
  echo -e "${GREEN} → Instalando $dir${NC}"
  mkdir -p ~/.config/$dir
  cp -r .config/$dir/* ~/.config/$dir/
done


echo -e "${YELLOW}[+] Copiando /wallpapers a ~/${NC}"
cp -r ./wallpapers ~/
echo -e "${GREEN}[✔] Instalación completada. Reinicia la sesión para aplicar cambios.${NC}"
