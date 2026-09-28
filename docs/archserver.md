# Arch Server

## Arch Linux

```shell
# Install package
sudo pacman -Syu package-name

# Sync databases and upgrade all packages
sudo pacman -Syu

# Install from AUR
sudo yay -S package-name

# Update everything including AUR
sudo yay -Syu
```

## Docker Status

```bash
docker ps -a --format "table {{.Names}}\t{{.RunningFor}}\t{{.Status}}"
```

