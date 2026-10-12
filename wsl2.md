# Laravel Development Environment Setup

## Ubuntu 26.04 LTS / WSL2 — Copy-and-Paste Guide

> [!CAUTION]
> **For an isolated local development machine only. Never use on production, shared hosts, or machines reachable by untrusted users.** This guide deliberately configures passwordless MySQL `root`, phpMyAdmin automatic login, and verbose PHP errors. Anyone who can reach the phpMyAdmin endpoint can administer your databases.

> [!IMPORTANT]
> **Execution model:** Run the blocks in order. Each block is self-contained and easy to update independently. Paste the entire block into a **Bash terminal inside Ubuntu**, except for the Windows PowerShell block. Commands stop on failure where practical. Prompts collect personal details at runtime; you do not need to edit placeholders.

### Stack

| Component                     | Target                               | Installation strategy                     |
| ----------------------------- | ------------------------------------ | ----------------------------------------- |
| Ubuntu                        | 26.04 LTS                            | WSL2 or native                            |
| PHP                           | 8.5 CLI + FPM                        | Ubuntu APT packages                       |
| MySQL                         | 8.4 LTS                              | Ubuntu APT packages; verify exact version |
| Apache                        | 2.x                                  | Ubuntu APT                                |
| phpMyAdmin                    | Ubuntu-supported version             | Ubuntu APT                                |
| Composer                      | Latest stable at install/update time | Verified official installer               |
| Laravel Installer             | Latest compatible                    | Composer global                           |
| Node.js                       | Latest release within 24.x           | NVM                                       |
| Bun                           | Latest stable at install/update time | Official installer                        |
| Git / GitHub CLI / GitLab CLI | Ubuntu repository versions           | Ubuntu APT                                |

> [!NOTE]
> **“Latest” has limits.** APT upgrades to versions published in your enabled Ubuntu repositories; it does not automatically switch PHP 8.5, MySQL 8.4, or Node 24 to a newer major line. `apt upgrade` also does not update software installed with NVM, Composer, or Bun. The dedicated update block below covers those separately. Review release notes before major upgrades.

### 1. Install Ubuntu on WSL2 (Windows PowerShell)

Skip this section on native Ubuntu. Run in **PowerShell as Administrator**:

```powershell
wsl --update
wsl --list --online
wsl --install -d Ubuntu-26.04
```

> [!WARNING]
> If `Ubuntu-26.04` is not listed, do not guess another distribution name. Install a supported distribution from `wsl --list --online` and confirm its release before continuing. **Never use `wsl --unregister` as an installation or repair step:** it permanently deletes the distribution's data.

### 2. Base system and prerequisites

```bash
set -e
. /etc/os-release
[ "$VERSION_ID" = "26.04" ] || { echo "ERROR: Ubuntu 26.04 is required; found ${PRETTY_NAME:-unknown}." >&2; false; }
sudo apt update
sudo DEBIAN_FRONTEND=noninteractive apt full-upgrade -y
sudo DEBIAN_FRONTEND=noninteractive apt install -y \
  ca-certificates curl wget gnupg git unzip zip zstd \
  build-essential software-properties-common tree htop acl
sudo apt autoremove -y
printf '\nOS: '; lsb_release -ds 2>/dev/null || cat /etc/os-release | grep PRETTY_NAME
printf 'Init: '; ps -p 1 -o comm=
```

> [!WARNING]
> The remaining service commands require **systemd**. If the output above is not `systemd` in WSL2, enable it using the next block, then run `wsl --shutdown` from PowerShell and reopen Ubuntu. Skip this block if systemd already works.

```bash
sudo install -d -m 755 /etc
printf '[boot]\nsystemd=true\n' | sudo tee /etc/wsl.conf
```

### 3. Install PHP, MySQL, Apache, phpMyAdmin and Git CLIs

APT is run **once** for the main stack. Check package candidates before installing so missing or incompatible packages fail visibly rather than silently substituting another version.

```bash
set -e
sudo apt update
for package in php8.5-cli php8.5-fpm mysql-server phpmyadmin gh glab; do
  candidate="$(apt-cache policy "$package" | awk '/Candidate:/ {print $2}')"
  [ -n "$candidate" ] && [ "$candidate" != '(none)' ] || {
    echo "ERROR: No APT candidate for $package" >&2
    false
  }
done

printf 'phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2\n' | sudo debconf-set-selections
sudo DEBIAN_FRONTEND=noninteractive apt install -y \
  php8.5-cli php8.5-fpm php8.5-bcmath php8.5-curl \
  php8.5-gd php8.5-intl php8.5-mbstring php8.5-mysql \
  php8.5-xml php8.5-zip php8.5-sqlite3 \
  php8.5-redis php8.5-msgpack php8.5-igbinary \
  php8.5-pgsql \
  mysql-server mysql-client apache2 phpmyadmin git gh glab

php -r 'if (PHP_MAJOR_VERSION !== 8 || PHP_MINOR_VERSION !== 5) {fwrite(STDERR, "ERROR: PHP 8.5 required\n"); exit(1);}'
sudo mysql -Nse 'SELECT VERSION();' | grep -E '^8\.4\.' >/dev/null || {
  echo 'ERROR: Expected MySQL 8.4 LTS; inspect installed repository packages.' >&2
  false
}
```

> [!ERROR]
> If the version check fails, **stop**. Do not continue with an unverified MySQL version or add an arbitrary third-party repository. Inspect `apt-cache policy mysql-server mysql-community-server` and the official Ubuntu/MySQL packaging documentation.

### 4. PHP configuration (CLI and FPM)

Use a separate override file rather than modifying stock `php.ini` or OPcache files. This is repeatable and survives package updates more cleanly.

```bash
set -e
sudo tee /etc/php/8.5/mods-available/local-development.ini >/dev/null <<'EOF'
memory_limit = 1024M
max_execution_time = 300
max_input_time = 300
upload_max_filesize = 512M
post_max_size = 520M
max_input_vars = 5000
max_file_uploads = 100
date.timezone = Asia/Dhaka
display_errors = On
display_startup_errors = On
log_errors = On
error_reporting = E_ALL
realpath_cache_size = 32M
realpath_cache_ttl = 120
opcache.enable = 1
opcache.enable_cli = 0
opcache.memory_consumption = 256
opcache.interned_strings_buffer = 32
opcache.max_accelerated_files = 50000
opcache.validate_timestamps = 1
opcache.revalidate_freq = 0
opcache.save_comments = 1
EOF
sudo phpenmod -v 8.5 -s cli local-development
sudo phpenmod -v 8.5 -s fpm local-development
sudo systemctl enable --now php8.5-fpm
sudo systemctl restart php8.5-fpm
php -v
php --ini
```

> [!TIP]
> To support uploads larger than 512 MB, change `upload_max_filesize` and `post_max_size` in this single block. Ensure `post_max_size` remains larger than `upload_max_filesize`.

### 5. MySQL root-only, passwordless local development

> [!CAUTION]
> The next block deliberately changes MySQL `root` authentication to an **empty password** using the modern `caching_sha2_password` plugin. This removes Ubuntu's default socket-only protection for `root` and permits local passwordless connections. **Never run it on a shared or network-accessible database.** `mysql_native_password` is not needed.

```bash
set -e
sudo systemctl enable --now mysql
sudo mysql <<'SQL'
ALTER USER 'root'@'localhost' IDENTIFIED WITH caching_sha2_password BY '';
SQL
mysql -u root -e 'SELECT CURRENT_USER(), VERSION();'
```

> [!WARNING]
> If MySQL rejects empty passwords because of a password-validation policy, **stop** rather than disabling the policy automatically. This guide assumes a fresh, isolated development installation. On an existing installation with a root password, the `sudo mysql` command may also require manual authentication.

### 6. Apache + localhost-only phpMyAdmin auto-login

Apache uses PHP-FPM. phpMyAdmin is restricted to requests from the local machine; verify any Windows/WSL2 port forwarding and firewall configuration separately.

```bash
set -e
sudo a2enmod rewrite proxy_fcgi setenvif headers
sudo a2enconf php8.5-fpm

if [ ! -e /etc/apache2/conf-available/phpmyadmin.conf ]; then
  sudo test -f /etc/phpmyadmin/apache.conf
  sudo ln -s /etc/phpmyadmin/apache.conf /etc/apache2/conf-available/phpmyadmin.conf
fi
sudo a2enconf phpmyadmin

sudo install -d -m 755 /etc/phpmyadmin/conf.d
sudo tee /etc/phpmyadmin/conf.d/99-local-autologin.php >/dev/null <<'PHP'
<?php
$cfg['Servers'][1]['auth_type'] = 'config';
$cfg['Servers'][1]['user'] = 'root';
$cfg['Servers'][1]['password'] = '';
$cfg['Servers'][1]['AllowNoPassword'] = true;
PHP

sudo tee /etc/apache2/conf-available/phpmyadmin-local-only.conf >/dev/null <<'APACHE'
<Location "/phpmyadmin">
    Require local
</Location>
<LocationMatch "(?i)^/phpmyadmin/">
    Require local
</LocationMatch>
APACHE
sudo a2enconf phpmyadmin-local-only
sudo apache2ctl configtest
sudo systemctl enable --now apache2
sudo systemctl restart php8.5-fpm apache2
```

Open **http://localhost/phpmyadmin**.

> [!WARNING]
> A local-only Apache rule is not a complete security boundary against other local users, compromised applications, reverse proxies, or unusual WSL networking configurations. Check actual reachability before storing sensitive data. phpMyAdmin package configuration may vary; if automatic login does not work, inspect `/etc/phpmyadmin/config.inc.php` and confirm that it loads `/etc/phpmyadmin/conf.d/*.php`.

### 7. Composer and Laravel Installer

The official installer signature is verified before execution. Run as your normal Linux user, not root.

```bash
set -e
installer="$(mktemp)"
trap 'rm -f "$installer"' EXIT
curl -fsSL https://getcomposer.org/installer -o "$installer"
expected="$(curl -fsSL https://composer.github.io/installer.sig)"
actual="$(php -r 'echo hash_file("sha384", $argv[1]);' "$installer")"
[ "$expected" = "$actual" ] || { echo 'ERROR: Composer signature mismatch' >&2; false; }
php "$installer" --install-dir=/tmp --filename=composer
sudo install -m 755 /tmp/composer /usr/local/bin/composer
rm -f /tmp/composer
composer global require laravel/installer
composer --version
```

### 8. Node.js 24 and Bun

Fetch the latest NVM installer release tag from the official GitHub API at execution time; install the latest compatible Node.js **24.x** and the latest stable Bun release.

```bash
set -e
nvm_tag="$(curl -fsSL https://api.github.com/repos/nvm-sh/nvm/releases/latest | php -r '$x=json_decode(stream_get_contents(STDIN),true); if (empty($x["tag_name"])) exit(1); echo $x["tag_name"];')"
curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/${nvm_tag}/install.sh" | bash
export NVM_DIR="$HOME/.nvm"
. "$NVM_DIR/nvm.sh"
nvm install 24
nvm alias default 24
curl -fsSL https://bun.sh/install | bash
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
node --version
npm --version
bun --version
```

> [!CAUTION]
> The NVM and Bun commands execute official remote installation scripts. Review upstream scripts and release notes if you require a fully auditable or reproducible installation. “Latest” means latest **at the moment you run the block**, not an unattended background upgrade.

### 9. Git identity, authentication, shell history and `cls`

No placeholders need editing. The terminal asks for your name and email, then optionally opens interactive GitHub/GitLab login flows. SSH key creation is intentionally not automated because it can overwrite existing keys or conflict with account-specific preferences.

```bash
set -e
read -r -p 'Git full name: ' git_name
read -r -p 'Git email address: ' git_email
[ -n "$git_name" ] && [[ "$git_email" == *@*.* ]] || {
  echo 'ERROR: A name and valid-looking email are required.' >&2
  false
}
git config --global user.name "$git_name"
git config --global user.email "$git_email"
git config --global init.defaultBranch main

shell_marker='# Laravel Local Development Shell Settings'
if ! grep -Fqx "$shell_marker" "$HOME/.bashrc"; then
  cat >> "$HOME/.bashrc" <<'EOF'

# Laravel Local Development Shell Settings
export HISTFILE="$HOME/.bash_history"
export HISTSIZE=10000
export HISTFILESIZE=0
export PATH="$HOME/.config/composer/vendor/bin:$HOME/.bun/bin:$PATH"
alias cls='clear'
EOF
fi

# Apply the settings to the current shell without requiring a restart.
export HISTFILE="$HOME/.bash_history"
export HISTSIZE=10000
export HISTFILESIZE=0
export PATH="$HOME/.config/composer/vendor/bin:$HOME/.bun/bin:$PATH"
alias cls='clear'

git config --global --list
printf '\nGitHub login: gh auth login\nGitLab login: glab auth login\n'
```

> [!NOTE]
> `HISTFILESIZE=0` is retained exactly as requested. Bash history behavior can vary with how history is written and shell sessions close; this is **not** a reliable privacy or audit-control mechanism. `cls` is a Bash alias and is available in interactive shells after reopening Ubuntu or running `source ~/.bashrc`.

To authenticate, run only the service(s) you use:

```bash
gh auth login
glab auth login
```

### 10. Future updates — one pasteable block

Run this block when you want to update the environment. It updates APT-managed packages, Composer, the Laravel Installer, the newest compatible Node.js 24.x release, and Bun. It does **not** force upgrades to new major PHP/MySQL/Node versions.

```bash
set -e
sudo apt update
sudo DEBIAN_FRONTEND=noninteractive apt upgrade -y
sudo apt autoremove -y
composer self-update --stable
composer global update laravel/installer --with-all-dependencies
export NVM_DIR="$HOME/.nvm"
. "$NVM_DIR/nvm.sh"
nvm install 24
nvm alias default 24
bun upgrade
sudo systemctl restart php8.5-fpm mysql apache2
printf '\nUpdate completed. Review any APT reboot notices.\n'
```

> [!IMPORTANT]
> This is an **on-demand update workflow**, not a scheduled background updater. Fully automatic major-version upgrades are intentionally avoided because they can break Laravel projects. `apt upgrade` can update PHP 8.5 and MySQL 8.4 within the repository's available patch releases; confirm the installed versions after updating.

### 11. Quick verification

```bash
set -e
printf '\nPHP: '; php -v | head -n 1
printf 'Composer: '; composer --version
printf 'Laravel Installer: '; laravel --version
printf 'MySQL: '; mysql -u root -Nse 'SELECT VERSION();'
printf 'Apache: '; apache2 -v | head -n 1
printf 'Node: '; node --version
printf 'Bun: '; bun --version
printf 'Git: '; git --version
printf 'GitHub CLI: '; gh --version | head -n 1
printf 'GitLab CLI: '; glab --version | head -n 1
printf '\nServices:\n'; systemctl is-active mysql php8.5-fpm apache2
printf '\nApache config:\n'; sudo apache2ctl configtest
printf '\nphpMyAdmin: http://localhost/phpmyadmin\n'
```

> [!TIP]
> For WSL2 performance, store projects in the Linux filesystem (for example, `~/projects`) rather than under `/mnt/c`. This guide deliberately does not create a Laravel project or an Apache VirtualHost.

---

**Maintenance note:** This guide favors small, independent, copy-and-paste blocks over one opaque installer. Edit a block in this Markdown file whenever your requirements change, and rerun only the relevant section. Validate changes on a disposable Ubuntu/WSL2 instance before relying on them.
