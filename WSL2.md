# UBUNTU 26.04 LTS ON WSL2 — PROFESSIONAL DEVELOPMENT ENVIRONMENT SETUP

## 01. WSL2 INSTALLATION & UBUNTU DISTRIBUTION MANAGEMENT

```powershell
wsl --install --no-distribution
wsl --update
wsl --list --online
wsl --install -d Ubuntu-26.04
wsl --list --verbose

# ⚠️ WARNING: Permanently deletes the distribution and its files
# wsl --unregister Ubuntu-26.04
```

---

## 02. SYSTEM PACKAGES & DEVELOPMENT DEPENDENCIES INSTALLATION

```bash
# 01. System Updates & Maintenance
sudo apt update && sudo apt full-upgrade -y
sudo apt autoclean && sudo apt autoremove --purge -y


# 02. Pre-configure phpMyAdmin Prompts (Prevents interactive popups)
echo "phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2" | sudo debconf-set-selections
echo "phpmyadmin phpmyadmin/dbconfig-install boolean false" | sudo debconf-set-selections


# 03. PHP 8.5 Runtime & Extensions
sudo apt install -y --no-install-recommends \
    php8.5 php8.5-{cli,fpm,common,bcmath,curl,gd,intl,mbstring,mysql,readline,redis,sqlite3,xml,zip}


# 04. Python 3 Runtime & Development Tools
sudo apt install -y --no-install-recommends \
    python3 python3-{pip,dev,venv}


# 05. Web Server, Database Services & Administration Tools
sudo apt install -y --no-install-recommends \
    apache2 sqlite3 mysql-server mysql-client redis-server redis-tools phpmyadmin


# 06. Development Tools, System Utilities & Monitoring
sudo apt install -y --no-install-recommends \
    git gh glab composer \
    curl wget gpg file tree zip unzip ca-certificates bind9-dnsutils iproute2 rsync zstd \
    htop nano less openssh-server
```

---

## 03. PHP 8.5 RUNTIME & PHP-FPM CONFIGURATION

```bash
# 01. PHP 8.5 - WSL2 Local Development (CLI & FPM)
sudo tee /etc/php/8.5/cli/conf.d/99-local-dev.ini /etc/php/8.5/fpm/conf.d/99-local-dev.ini >/dev/null <<'EOF'
; Resource Limits
memory_limit                    = 512M
max_execution_time              = 120
max_input_time                  = 120
max_input_vars                  = 10000

; File Uploads
file_uploads                    = On
upload_max_filesize             = 1024M
post_max_size                   = 1100M
max_file_uploads                = 50

; General
default_socket_timeout          = 60
date.timezone                   = Asia/Dhaka
short_open_tag                  = Off

; Error Reporting
display_errors                  = On
display_startup_errors          = On
log_errors                      = On
error_reporting                 = E_ALL
html_errors                     = On

; Realpath Cache
realpath_cache_size             = 16M
realpath_cache_ttl              = 120

; Assertions
zend.assertions                 = 1
assert.exception                = 1

; OPcache
opcache.enable                  = 1
opcache.enable_cli              = 0
opcache.memory_consumption      = 256
opcache.interned_strings_buffer = 16
opcache.max_accelerated_files   = 32531
opcache.max_wasted_percentage   = 5
opcache.validate_timestamps     = 1
opcache.revalidate_freq         = 0
opcache.save_comments           = 1
EOF


# 02. Enable & Restart PHP-FPM
sudo systemctl enable --now php8.5-fpm
sudo systemctl restart php8.5-fpm
```

---

## 04. COMPOSER & LARAVEL DEVELOPMENT TOOLS INSTALLATION

```bash
# 01. Configure Composer Global PATH
grep -qxF 'export PATH="$HOME/.config/composer/vendor/bin:$PATH"' "$HOME/.bashrc" || echo 'export PATH="$HOME/.config/composer/vendor/bin:$PATH"' >> "$HOME/.bashrc"
source "$HOME/.bashrc"
composer --version


# 02. Install Laravel Installer & Laravel LSP
composer global require laravel/installer laravel/lsp
laravel -v
```

---

## 05. NODE.JS (LATEST LTS), NVM & BUN RUNTIME CONFIGURATION

```bash
# 01. Install Latest NVM, Node.js LTS & NPM
NVM_LATEST=$(curl -fsSL https://api.github.com/repos/nvm-sh/nvm/releases/latest | grep '"tag_name":' | cut -d'"' -f4)
curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_LATEST}/install.sh" | bash
source "$HOME/.nvm/nvm.sh"

nvm install --lts
nvm alias default 'lts/*'
source "$HOME/.bashrc"
node --version && npm --version && nvm --version


# 02. Install Bun Runtime & Package Manager (Always Latest)
curl -fsSL https://bun.sh/install | bash
source "$HOME/.bashrc"
bun --version


# 03. Update NPM to Latest & Install npm-check-updates Globally
npm install -g npm@latest npm-check-updates
```

---

## 06. MYSQL LTS INSTALLATION & DATABASE CONFIGURATION

```bash
# 01. Enable & Restart MySQL Service
sudo systemctl enable --now mysql
sudo systemctl restart mysql


# 02. Configure MySQL Root Authentication (Passwordless Local Dev)
sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH caching_sha2_password BY ''; FLUSH PRIVILEGES;"


# 03. Verify MySQL Installation
mysql -u root -e "SELECT VERSION(), @@hostname, USER();"
```

---

## 07. APACHE2 WEB SERVER & PHP-FPM INTEGRATION

```bash
# 01. Enable Apache Modules & PHP-FPM
sudo a2enmod rewrite headers proxy_fcgi setenvif
sudo a2dismod php8.5 2>/dev/null || true
sudo a2enconf php8.5-fpm


# 02. Enable & Restart Services
sudo systemctl enable --now php8.5-fpm apache2
sudo systemctl restart php8.5-fpm apache2
```

---

## 08. PHPMYADMIN INSTALLATION & ADMINISTRATION CONFIGURATION

```bash
# 01. Configure Automatic Login
sudo tee /etc/phpmyadmin/conf.d/99-autologin.php >/dev/null <<'EOF'
<?php
$cfg['Servers'][1]['auth_type']       = 'config';
$cfg['Servers'][1]['user']            = 'root';
$cfg['Servers'][1]['password']        = '';
$cfg['Servers'][1]['AllowNoPassword'] = true;
EOF


# 02. Install DarkOrange Theme
sudo git clone --depth 1 https://github.com/atikhasan392/DarkOrange.git /usr/share/phpmyadmin/themes/DarkOrange 2>/dev/null || true
```

---

## 09. REDIS SERVER INSTALLATION & CONNECTION VERIFICATION

```bash
# 01. Enable Redis & Verify Connection
sudo systemctl enable --now redis-server
redis-server --version
redis-cli ping
```

---

## 10. GIT VERSION CONTROL, SSH & GITHUB/GITLAB AUTHENTICATION

```bash
# 01. Git Global Configuration
GIT_EMAIL="YOUR_EMAIL"

git config --global user.name "ATik HaSan"
git config --global user.email "$GIT_EMAIL"
git config --global init.defaultBranch main
git config --global core.autocrlf input
git config --global core.editor nano
git config --global fetch.prune true
git config --global pull.rebase true
git config --global rebase.autoStash true
git config --global push.default simple
git config --global push.autoSetupRemote true
git config --global rerere.enabled true


# 02. Generate SSH Keys (Non-interactive)
mkdir -p ~/.ssh && chmod 700 ~/.ssh
ssh-keygen -t ed25519 -C "$GIT_EMAIL" -f ~/.ssh/id_ed25519_github -N ""
ssh-keygen -t ed25519 -C "$GIT_EMAIL" -f ~/.ssh/id_ed25519_gitlab -N ""


# 03. Configure SSH Hosts
cat > ~/.ssh/config <<'EOF'
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519_github
    IdentitiesOnly yes
    AddKeysToAgent yes

Host gitlab.com
    HostName gitlab.com
    User git
    IdentityFile ~/.ssh/id_ed25519_gitlab
    IdentitiesOnly yes
    AddKeysToAgent yes
EOF

chmod 600 ~/.ssh/config


# 04. Configure SSH Agent
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519_github
ssh-add ~/.ssh/id_ed25519_gitlab


# 05. Display Public SSH Keys
echo -e "\nGITHUB PUBLIC KEY:" && cat ~/.ssh/id_ed25519_github.pub
echo -e "\nGITLAB PUBLIC KEY:" && cat ~/.ssh/id_ed25519_gitlab.pub

# Add keys:
# https://github.com/settings/keys
# https://gitlab.com/-/user_settings/ssh_keys


# 06. GitHub & GitLab Authentication
gh auth login && gh auth setup-git
glab auth login && glab auth setup-git


# 07. Verify Configuration
git config --global --list
ssh -T git@github.com
ssh -T git@gitlab.com
gh auth status
glab auth status
```

---

## 11. OPENSSH SERVER INSTALLATION & CONFIGURATION

```bash
# 01. Configure SSH Daemon Settings (Drop-in file)
sudo tee /etc/ssh/sshd_config.d/99-wsl-ssh.conf >/dev/null <<'EOF'
Port 22
ListenAddress 0.0.0.0
PasswordAuthentication yes
PubkeyAuthentication yes
EOF


# 02. Validate Config, Enable, Restart & Check Listening Port
sudo sshd -t
sudo systemctl enable --now ssh
sudo systemctl restart ssh
ss -tlnp | grep 22
hostname -I
```

```powershell
# 01. (Optional) Ensure mirrored networking is set if you need direct LAN IP access
# Add-Content "$env:UserProfile\.wslconfig" "`n[wsl2]`nnetworkingMode=mirrored"

# 02. Shutdown WSL to apply config/network resets
wsl --shutdown

# 03. Allow inbound TCP port 22 through Windows Firewall
if (-not (Get-NetFirewallRule -Name "WSL2-SSH" -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -Name "WSL2-SSH" -DisplayName "WSL2 SSH Server" -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
}

# 04. Start WSL back up so systemd brings up services
wsl -d Ubuntu-26.04 --exec true
```

```bash
# From Windows:
ssh your_ubuntu_username@localhost -p 22

# From another device on the same network (with mirrored mode):
ssh your_ubuntu_username@<windows-ip-address> -p 22
```

---

## 12. CLOUDFLARE TUNNEL INSTALLATION & SERVICE CONFIGURATION

```bash
# 01. Add Cloudflare GPG Key & Repository
sudo mkdir -p --mode=0755 /usr/share/keyrings
curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | sudo tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null
echo 'deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared any main' | sudo tee /etc/apt/sources.list.d/cloudflared.list >/dev/null


# 02. Install Cloudflared
sudo apt update && sudo apt install -y cloudflared


# 03. Install as Service
# sudo cloudflared service install <YOUR_TUNNEL_TOKEN>
```

---

## 13. BASH SHELL CUSTOMIZATION & ENVIRONMENT OPTIMIZATION

```bash
# 01. Configure Bash History and Terminal Aliases
cat >> "$HOME/.bashrc" <<'EOF'

# Shell History Configuration
export HISTFILE=/dev/null
export HISTSIZE=5000
export HISTCONTROL=ignoreboth:erasedups
unset HISTIGNORE

# Custom Terminal Aliases
alias cls='clear'
EOF

source "$HOME/.bashrc"
```
