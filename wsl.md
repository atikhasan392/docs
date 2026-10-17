# UBUNTU 26.04 LTS ON WSL2 – DEVELOPMENT SETUP GUIDE

## TARGET STACK

| COMPONENT                                | TARGET / INSTALLATION POLICY                                          |
| ---------------------------------------- | --------------------------------------------------------------------- |
| WSL                                      | WSL2, CURRENT AVAILABLE STABLE RELEASE                                |
| UBUNTU                                   | 26.04 LTS                                                             |
| PHP                                      | UBUNTU PHP 8.5 PACKAGES; CLI + FPM                                    |
| COMPOSER, LARAVEL INSTALLER, LARAVEL LSP | COMPATIBLE CURRENT VERSIONS                                           |
| MYSQL                                    | UBUNTU MYSQL 8.4 SERIES; VERIFY INSTALLED VERSION                     |
| REDIS                                    | UBUNTU REPOSITORY VERSION BY DEFAULT; REDIS **8.4 IS NOT GUARANTEED** |
| APACHE                                   | UBUNTU APACHE 2.4 SERIES                                              |
| PHPMYADMIN                               | UBUNTU REPOSITORY VERSION                                             |
| NODE.JS                                  | NODE.JS **24.X** VIA NODESOURCE REPOSITORY                            |
| BUN                                      | CURRENT BUN INSTALLER RELEASE                                         |
| GIT / GITHUB CLI / GITLAB CLI            | VERSIONS AVAILABLE FROM CONFIGURED REPOSITORIES                       |

---

### 01. INSTALL WSL2 (POWERSHELL — ADMINISTRATOR)

```powershell
wsl --install
wsl --update
wsl --list --online
wsl --install -d Ubuntu-26.04
wsl --list --verbose

# ⚠️ WARNING: Permanently deletes the distribution and its files
# wsl --unregister Ubuntu-26.04
```

---

### 02. INSTALL APT PACKAGES

```bash
# 01. Update the system
sudo apt update
sudo apt full-upgrade -y
sudo apt autoclean
sudo apt autoremove --purge -y

# 02. PHP 8.5 and extensions
sudo apt install -y --no-install-recommends \
    php8.5 php8.5-fpm php8.5-cli php8.5-common \
    php8.5-bcmath php8.5-curl php8.5-xml \
    php8.5-gd php8.5-mbstring php8.5-mysql \
    php8.5-zip php8.5-intl php8.5-readline \
    php8.5-redis php8.5-msgpack php8.5-igbinary \
    php8.5-sqlite3 php8.5-pgsql \
    php8.5-xdebug php8.5-dev

# 03. Essential utilities
sudo apt install -y --no-install-recommends \
    bash-completion build-essential ca-certificates \
    curl wget gpg gnupg lsb-release \
    software-properties-common file openssl pkg-config

# 04. Git & CLI tools
sudo apt install -y --no-install-recommends \
    git git-lfs gh glab

# 05. Web server, databases and cache
sudo apt install -y --no-install-recommends \
    apache2 apache2-utils phpmyadmin \
    mysql-server mysql-client sqlite3 \
    redis-server redis-sentinel redis-tools

# 06. Networking and files
sudo apt install -y --no-install-recommends \
    bind9-dnsutils net-tools iproute2 \
    rsync unzip zip zstd tree

# 07. Terminal and monitoring
sudo apt install -y --no-install-recommends \
    htop jq nano vim tmux less

# 08. Process and system utilities
sudo apt install -y --no-install-recommends \
    acl cron supervisor inotify-tools libnss3-tools
```

---

### 03. CONFIGURE PHP-8.5 (CLI + FPM)

```bash
# 01. Local development settings
cat > /tmp/99-local-dev.ini <<'EOF'
; LOCAL DEVELOPMENT OVERRIDES
memory_limit           = 512M
max_execution_time     = 300
max_input_time         = 300
file_uploads           = On
upload_max_filesize    = 1024M
post_max_size          = 1280M
max_file_uploads       = 100
max_input_vars         = 10000
default_socket_timeout = 60
date.timezone          = Asia/Dhaka
display_errors         = On
display_startup_errors = On
log_errors             = On
error_reporting        = E_ALL
realpath_cache_size    = 32M
realpath_cache_ttl     = 120
EOF

sudo install -m 644 /tmp/99-local-dev.ini /etc/php/8.5/cli/conf.d/99-local-dev.ini
sudo install -m 644 /tmp/99-local-dev.ini /etc/php/8.5/fpm/conf.d/99-local-dev.ini

# 02. OPcache overrides
cat > /tmp/99-local-opcache.ini <<'EOF'
; LOCAL OPCACHE OVERRIDES
opcache.enable                  = 1
opcache.enable_cli              = 0
opcache.memory_consumption      = 256
opcache.interned_strings_buffer = 32
opcache.max_accelerated_files   = 50000
opcache.validate_timestamps     = 1
opcache.revalidate_freq         = 0
opcache.save_comments           = 1
opcache.enable_file_override    = 0
opcache.file_update_protection  = 2
opcache.max_wasted_percentage   = 5
opcache.use_cwd                 = 1
opcache.validate_permission     = 0
EOF

sudo install -m 644 /tmp/99-local-opcache.ini /etc/php/8.5/cli/conf.d/99-local-opcache.ini
sudo install -m 644 /tmp/99-local-opcache.ini /etc/php/8.5/fpm/conf.d/99-local-opcache.ini

# 03. Enable FPM and verify
sudo php-fpm8.5 -t
sudo systemctl enable --now php8.5-fpm
sudo systemctl restart php8.5-fpm

php -v
php --ini
php -m
php -i | grep -E 'memory_limit|upload_max_filesize|post_max_size|max_input_vars|date.timezone|opcache.enable'
```

---

### 04. INSTALL LARAVEL INSTALLER AND LARAVEL LSP

```bash
curl -sS https://getcomposer.org/installer | sudo php -- --install-dir=/usr/local/bin --filename=composer
composer global require laravel/installer
composer global require laravel/lsp

composer --version
laravel --version
command -v laravel-lsp
```

---

### 05. INSTALL NODE.JS 24 AND BUN

```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.8/install.sh | bash
\. "$HOME/.nvm/nvm.sh"
nvm install 24
node --version
npm --version

curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.8/install.sh | bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
nvm install 24
nvm alias default 24

nvm --version
node --version
npm --version

# Review third-party installer scripts before running them on a system you do not fully control.
curl -fsSL https://bun.sh/install -o /tmp/install-bun.sh
bash /tmp/install-bun.sh
bun --version
```

---

### 06. CONFIGURE MYSQL 8.4

```bash
sudo systemctl enable --now mysql

# Configure Passwordless Root Access (Local Development Only)
sudo mysql <<'SQL'
    ALTER USER 'root'@'localhost' IDENTIFIED WITH caching_sha2_password BY '';
    FLUSH PRIVILEGES;
SQL

# Verify MySQL
mysql -u root -e "SELECT VERSION(), @@hostname, USER();"
```

---

### 07. CONFIGURE APACHE + PHP-FPM

```bash
sudo a2enmod rewrite headers proxy_fcgi setenvif
sudo a2enconf php8.5-fpm

sudo systemctl enable --now php8.5-fpm
sudo systemctl enable --now apache2
sudo systemctl restart apache2
```

---

### 08. CONFIGURE PHPMYADMIN (SAFE LOCAL LOGIN)

```bash
echo "phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2" | sudo debconf-set-selections

# Enable Auto-Login
sudo tee /etc/phpmyadmin/conf.d/99-autologin.php >/dev/null <<'EOF'
<?php
$cfg['Servers'][1]['auth_type']       = 'config';
$cfg['Servers'][1]['user']            = 'root';
$cfg['Servers'][1]['password']        = '';
$cfg['Servers'][1]['AllowNoPassword'] = true;
EOF

cd /usr/share/phpmyadmin/themes && sudo git clone https://github.com/atikhasan392/DarkOrange.git && cd ~
```

---

## 09. CONFIGURE AND VERIFY REDIS

```bash
sudo systemctl enable --now redis-server
redis-server --version
redis-cli ping
```

---

## 10. CONFIGURE GIT, SSH, GITHUB CLI AND GITLAB CLI

```bash
# 01. Git identity and defaults
git config --global user.name "YOUR_NAME"
git config --global user.email "YOUR_EMAIL"
git config --global init.defaultBranch main
git config --global core.autocrlf input
git config --global core.editor nano
git config --global fetch.prune true
git config --global pull.rebase false
git config --global push.autoSetupRemote true

git config --global --list

#02. One SSH key for GitHub and GitLab
mkdir -p ~/.ssh
chmod 700 ~/.ssh

if [ ! -f ~/.ssh/id_ed25519 ]; then
    ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -C "YOUR_EMAIL"
fi

cat ~/.ssh/id_ed25519.pub

# 03. GitHub CLI
gh auth login --hostname github.com --git-protocol ssh --web
gh auth status
gh config list

# 04. GitLab CLI
glab auth login
glab auth status
glab config list

# 05. Verify SSH
ssh -T git@github.com
ssh -T git@gitlab.com
```

Add the **public** key (the `.pub` file), never the private key, to:

- GitHub: <https://github.com/settings/keys>
- GitLab: <https://gitlab.com/-/user_settings/ssh_keys>

---

### 11. CONFIGURE TIMEZONE, BASH HISTORY AND ALIASES

```bash
# Timezone
sudo timedatectl set-timezone Asia/Dhaka
timedatectl
```

```bash
cat > ~/.bash_custom <<'EOF'
# --------------------------------------------------
# BASH HISTORY
# --------------------------------------------------
export HISTFILE="$HOME/.bash_history"
export HISTSIZE=10000
export HISTFILESIZE=20000
export HISTCONTROL=ignoreboth:erasedups
unset HISTIGNORE
shopt -s histappend

# --------------------------------------------------
# COMPOSER GLOBAL BINARIES
# --------------------------------------------------
export PATH="$HOME/.config/composer/vendor/bin:$PATH"

# --------------------------------------------------
# BUN GLOBAL BINARIES
# --------------------------------------------------
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# --------------------------------------------------
# NVM
# --------------------------------------------------
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

# --------------------------------------------------
# TERMINAL ALIASES
# --------------------------------------------------
alias cls='clear'
EOF

grep -qxF '[ -f "$HOME/.bash_custom" ] && source "$HOME/.bash_custom"' ~/.bashrc || echo '[ -f "$HOME/.bash_custom" ] && source "$HOME/.bash_custom"' >> ~/.bashrc

source ~/.bashrc
# nano .bash_custom
```

### 12. FINAL HEALTH CHECK

```bash
lsb_release -a
php -v
composer --version
laravel --version
node --version
npm --version
bun --version
git --version
```

```bash
sudo apache2ctl configtest
sudo php-fpm8.5 -t
systemctl is-active apache2 php8.5-fpm mysql redis-server
sudo mysql -e 'SELECT VERSION();'
redis-cli ping
```

```bash
curl -I http://localhost/
curl -I http://localhost/phpmyadmin/
```

## References and maintenance notes

- Ubuntu 26.04 release notes: <https://documentation.ubuntu.com/release-notes/26.04/summary-for-lts-users/>
- Ubuntu PHP packages: <https://packages.ubuntu.com/resolute/php/>
- Laravel LSP: <https://github.com/laravel/lsp>
- NodeSource: <https://deb.nodesource.com/>
- Redis APT installation: <https://redis.io/docs/latest/operate/oss_and_stack/install/install-stack/apt/>
- GitHub SSH documentation: <https://docs.github.com/en/authentication/connecting-to-github-with-ssh>
- GitLab SSH documentation: <https://docs.gitlab.com/user/ssh/>

**Important differences from the original draft:** Fixed the missing line-continuation before `composer nodejs npm`; removed automatic blank-password MySQL root access and phpMyAdmin root auto-login; moved Node.js 24 installation to its own source; treated Redis 8.4 as an explicit pinning requirement rather than a guaranteed Ubuntu package version; replaced brittle `php.ini` substitutions with readable override files; consolidated repeated installations; avoided recursive `.bashrc` sourcing and repeated append operations; added verification commands.
