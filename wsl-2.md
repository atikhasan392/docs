# Laravel Development Environment — Ubuntu 26.04 LTS / WSL2

> [!CAUTION]
> **Local development only. Never deploy this configuration to production or expose it to a public network.** This setup enables detailed PHP errors, a fixed MySQL root password, and phpMyAdmin automatic authentication. Treat the machine and its backups as containing credentials.

## Stack and version policy

| Component                    | Target                 | Installation policy                                                   |
| ---------------------------- | ---------------------- | --------------------------------------------------------------------- |
| Ubuntu                       | 26.04 LTS (`resolute`) | Official Ubuntu updates/security repositories                         |
| WSL                          | WSL2                   | Current version distributed by Microsoft                              |
| PHP                          | 8.5 CLI + FPM (NTS)    | Latest available Ubuntu 26.04 PHP 8.5 package updates                 |
| Composer / Laravel installer | Latest stable          | Official Composer installer / Composer global install                 |
| MySQL                        | 8.4 LTS                | **Verify package candidate is 8.4 before installation**               |
| Apache                       | 2.x                    | Ubuntu updates/security repositories                                  |
| phpMyAdmin                   | Ubuntu-packaged stable | Ubuntu updates/security repositories; not necessarily upstream latest |
| Node.js                      | 24 LTS                 | Latest available Node 24 release through nvm                          |
| Bun                          | Latest stable          | Official Bun installer                                                |
| Git, GitHub CLI, GitLab CLI  | Latest available       | Ubuntu repositories (may lag upstream)                                |

> [!IMPORTANT]
> “Latest” means the latest **available and compatible** release in the specified version series and repository. `apt install` alone does not guarantee the newest upstream release. Check the version verification section before relying on this setup.

## Prerequisites

- Fresh Ubuntu 26.04 LTS, ideally on WSL2 with systemd enabled.
- Sudo privileges and internet access.
- At least 10 GB free disk space (more recommended for projects and databases).
- Run Linux commands in Ubuntu Bash, not PowerShell.
- Use an **Ubuntu Linux filesystem** (for example `~/code`) for Laravel projects rather than `/mnt/c` for better WSL performance.

## 1. Install WSL2 (Windows PowerShell, Administrator)

```powershell
wsl --update
wsl --list --online
wsl --install -d Ubuntu-26.04
wsl --list --verbose

# DANGER: This irreversibly deletes the distribution and all its data.
# wsl --unregister Ubuntu-26.04
```

If the distribution name differs in `wsl --list --online`, use the name actually listed. For native Ubuntu, skip this section.

### WSL2 systemd (only if necessary)

```bash
ps -p 1 -o comm=
```

If this does not print `systemd`, enable it and restart the distribution from Windows:

```bash
sudo tee /etc/wsl.conf >/dev/null <<'EOF_WSL'
[boot]
systemd=true
EOF_WSL
```

```powershell
wsl --shutdown
```

Open Ubuntu again, then confirm `ps -p 1 -o comm=` prints `systemd`.

## 2. Update Ubuntu and install essentials

```bash
set -e
. /etc/os-release
[ "$ID" = ubuntu ] && [ "$VERSION_ID" = '26.04' ] || {
  echo 'This guide requires Ubuntu 26.04 LTS.' >&2
  exit 1
}

sudo apt update
sudo apt full-upgrade -y
sudo apt autoremove -y
sudo apt install -y \
  curl wget git gnupg ca-certificates lsb-release \
  apt-transport-https software-properties-common zstd \
  zip unzip build-essential tree net-tools htop \
  openssh-client jq
sudo add-apt-repository -y universe
sudo apt update
```

## 3. PHP 8.5 (CLI + FPM)

Ubuntu 26.04 publishes PHP 8.5 packages. Use Ubuntu's maintained packages instead of adding an unnecessary third-party PHP PPA.

```bash
sudo apt install -y \
  php8.5 php8.5-fpm php8.5-cli php8.5-common \
  php8.5-bcmath php8.5-curl php8.5-xml php8.5-gd \
  php8.5-mbstring php8.5-mysql php8.5-zip \
  php8.5-intl php8.5-readline php8.5-redis \
  php8.5-msgpack php8.5-igbinary php8.5-sqlite3 \
  php8.5-pgsql

sudo systemctl enable --now php8.5-fpm
php -v
php -m
systemctl status php8.5-fpm --no-pager
```

If an extension is unavailable, check `apt-cache policy <package>`; do not silently install packages for a different Ubuntu release.

### PHP development configuration

Use separate, dedicated `conf.d` files rather than brittle substitutions in `php.ini`. The values apply to both CLI and FPM.

```bash
for SAPI in cli fpm; do
  sudo tee "/etc/php/8.5/$SAPI/conf.d/99-local-development.ini" >/dev/null <<'EOF_PHP'
memory_limit = 1024M
max_execution_time = 300
max_input_time = 300
upload_max_filesize = 5120M
post_max_size = 5120M
max_input_vars = 5000
max_file_uploads = 100
date.timezone = Asia/Dhaka
display_errors = On
display_startup_errors = On
log_errors = On
error_reporting = E_ALL
realpath_cache_size = 32M
realpath_cache_ttl = 120
EOF_PHP
done
```

### OPcache for local development

```bash
for SAPI in cli fpm; do
  sudo tee "/etc/php/8.5/$SAPI/conf.d/99-local-opcache.ini" >/dev/null <<'EOF_OPCACHE'
opcache.enable=1
opcache.enable_cli=1
opcache.memory_consumption=256
opcache.interned_strings_buffer=32
opcache.max_accelerated_files=50000
opcache.validate_timestamps=1
opcache.revalidate_freq=0
opcache.save_comments=1
EOF_OPCACHE
done

sudo systemctl restart php8.5-fpm
php --ini
php -i | grep -E 'memory_limit|upload_max_filesize|post_max_size|max_input_vars|date.timezone|display_errors|error_reporting|opcache.enable|opcache.revalidate_freq'
```

> [!NOTE]
> A 5 GB PHP upload limit also requires compatible Apache request limits and application validation. PHP CLI and FPM are separate processes; check both configurations when troubleshooting.

## 4. Composer and Laravel installer

Verify the Composer installer signature against the current official signature before executing it.

```bash
cd "$HOME"
EXPECTED_SIGNATURE="$(curl -fsSL https://composer.github.io/installer.sig)"
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
ACTUAL_SIGNATURE="$(php -r "echo hash_file('sha384', 'composer-setup.php');")"
[ "$EXPECTED_SIGNATURE" = "$ACTUAL_SIGNATURE" ] || {
  rm -f composer-setup.php
  echo 'Composer installer signature mismatch.' >&2
  exit 1
}
php composer-setup.php --install-dir="$HOME" --filename=composer.phar
rm composer-setup.php
sudo mv "$HOME/composer.phar" /usr/local/bin/composer
composer --version

composer global require laravel/installer
```

Add the Composer global executable directory to `PATH` (the directory is determined by Composer rather than assumed):

```bash
COMPOSER_BIN="$(composer global config bin-dir --absolute)"
printf '\nexport PATH="%s:$PATH"\n' "$COMPOSER_BIN" >> "$HOME/.bashrc"
export PATH="$COMPOSER_BIN:$PATH"
laravel --version
```

## 5. Node.js 24 LTS and Bun

Use the official nvm installation instructions to select the current stable nvm release. The following command fetches the **latest published nvm release tag** from GitHub, instead of hard-coding a tag.

```bash
NVM_TAG="$(curl -fsSL https://api.github.com/repos/nvm-sh/nvm/releases/latest | jq -r '.tag_name')"
[ -n "$NVM_TAG" ] && [ "$NVM_TAG" != null ] || exit 1
curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_TAG}/install.sh" -o /tmp/install-nvm.sh
bash /tmp/install-nvm.sh
rm /tmp/install-nvm.sh
export NVM_DIR="$HOME/.nvm"
[ ! -s "$NVM_DIR/nvm.sh" ] || . "$NVM_DIR/nvm.sh"
nvm install 24
nvm alias default 24
nvm use 24
node --version
npm --version
```

```bash
curl -fsSL https://bun.sh/install -o /tmp/install-bun.sh
bash /tmp/install-bun.sh
rm /tmp/install-bun.sh
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
bun --version
```

> [!WARNING]
> Downloading and executing remote installation scripts trusts their maintainers and distribution channels. Inspect the downloaded scripts before running them in higher-assurance environments. The nvm GitHub API may be rate-limited.

## 6. MySQL 8.4 LTS — version-checked installation

**Do not assume** Ubuntu's generic `mysql-server` package is MySQL 8.4. First inspect the repository candidate:

```bash
sudo apt update
apt-cache policy mysql-server mysql-server-8.4 mysql-community-server
```

### Option A — Ubuntu package (only if candidate is 8.4)

```bash
MYSQL_CANDIDATE="$(apt-cache policy mysql-server-8.4 | awk '/Candidate:/ {print $2}')"
if [[ "$MYSQL_CANDIDATE" == 8.4.* ]]; then
  sudo apt install -y mysql-server-8.4 mysql-client-8.4
else
  echo 'MySQL 8.4 is not available from the configured Ubuntu repositories.' >&2
  echo 'Use Option B after checking official Oracle repository support.' >&2
fi
```

### Option B — Oracle MySQL APT repository (only if Ubuntu 26.04 is supported)

Open the [official MySQL APT repository instructions](https://dev.mysql.com/doc/refman/8.4/en/linux-installation-apt-repo.html), download the current `mysql-apt-config` package for a **supported Ubuntu release**, verify the package/source, and choose **MySQL 8.4 LTS**. Do **not** point Ubuntu 26.04 at an older Ubuntu codename repository: mixing distributions can break dependency resolution.

Once the Oracle repository has been configured **for this exact Ubuntu release**, verify the candidate and install:

```bash
sudo apt update
apt-cache policy mysql-community-server
MYSQL_CANDIDATE="$(apt-cache policy mysql-community-server | awk '/Candidate:/ {print $2}')"
if [[ "$MYSQL_CANDIDATE" == 8.4.* ]]; then
  sudo apt install -y mysql-community-server mysql-community-client
else
  echo 'No verified MySQL 8.4 candidate. Stop here; do not install a different series.' >&2
  exit 1
fi
```

**Important:** If neither source offers a compatible 8.4 package, this section cannot be completed safely as written. Use a verified MySQL 8.4 container or wait for an officially supported package; do not substitute another version silently.

### Configure MySQL for loopback-only development

After installing MySQL 8.4:

```bash
sudo systemctl enable --now mysql
sudo tee /etc/mysql/mysql.conf.d/99-local-development.cnf >/dev/null <<'EOF_MYSQL'
[mysqld]
bind-address = 127.0.0.1
mysqlx-bind-address = 127.0.0.1
EOF_MYSQL
sudo systemctl restart mysql
mysql --version
sudo mysql -e 'SELECT VERSION();'
```

### Set the local root password

The documented default is `LocalDev@2026!` (change it before reusing the guide on another machine). This deliberately changes Ubuntu's common passwordless socket-root workflow to password authentication.

```bash
sudo mysql <<'EOF_SQL'
ALTER USER 'root'@'localhost'
  IDENTIFIED WITH caching_sha2_password BY 'LocalDev@2026!';
EOF_SQL

mysql -u root -p -e 'SELECT VERSION(), CURRENT_USER();'
```

Enter `LocalDev@2026!` when prompted. After the change, `sudo mysql` without `-p` will generally no longer authenticate as root. Avoid `-pPASSWORD` because it can expose credentials in shell history/process arguments.

> [!CAUTION]
> The password is visible in this guide and the terminal heredoc. This is acceptable **only for an isolated disposable local development environment**. For anything shared, remotely accessible, or production-like, generate a unique secret and avoid storing it in plaintext.

## 7. Apache + PHP-FPM

```bash
sudo apt install -y apache2
sudo a2dismod php8.5 2>/dev/null || true
sudo a2enmod rewrite proxy_fcgi setenvif headers
sudo a2enconf php8.5-fpm

# Bind Apache to loopback; replace the default listener only on a fresh local install.
sudo sed -i 's/^Listen 80$/Listen 127.0.0.1:80/' /etc/apache2/ports.conf
sudo apache2ctl configtest
sudo systemctl enable --now apache2
sudo systemctl restart apache2
curl -I http://127.0.0.1/
```

For each Laravel project, point the Apache virtual host's `DocumentRoot` at the project's `public/` directory and enable the appropriate directory `AllowOverride` or rewrite rules. Never serve the project root directly.

## 8. phpMyAdmin — automatic localhost login

Ubuntu 26.04 offers a packaged phpMyAdmin release. This uses Ubuntu's security-maintained package, **not a guarantee of the newest upstream version**.

```bash
sudo apt install -y phpmyadmin
```

If the installer asks for a web server, select Apache. If it asks whether to configure a database with `dbconfig-common`, you may choose **No** for this local root-login-only setup. Enable Apache integration explicitly:

```bash
sudo ln -sfn /etc/phpmyadmin/apache.conf /etc/apache2/conf-available/phpmyadmin.conf
sudo a2enconf phpmyadmin
sudo apache2ctl configtest
```

Configure automatic login to the local MySQL root account:

```bash
sudo install -d -m 755 /etc/phpmyadmin/conf.d
sudo tee /etc/phpmyadmin/conf.d/99-local-autologin.php >/dev/null <<'EOF_PMA'
<?php
$cfg['Servers'][1]['host'] = '127.0.0.1';
$cfg['Servers'][1]['connect_type'] = 'tcp';
$cfg['Servers'][1]['auth_type'] = 'config';
$cfg['Servers'][1]['user'] = 'root';
$cfg['Servers'][1]['password'] = 'LocalDev@2026!';
$cfg['Servers'][1]['AllowNoPassword'] = false;
EOF_PMA
sudo chmod 640 /etc/phpmyadmin/conf.d/99-local-autologin.php
sudo chown root:www-data /etc/phpmyadmin/conf.d/99-local-autologin.php
sudo systemctl restart php8.5-fpm apache2
```

> [!IMPORTANT]
> Confirm `/etc/phpmyadmin/config.inc.php` actually loads `conf.d/*.php` (Ubuntu's packaged configuration generally does). If it does not, this override will have no effect. Also confirm that server index `1` is the desired configured server. A config-auth login may retain access as root for anyone able to reach this web interface; keep Apache bound to loopback and do not forward this port to untrusted machines.

Open: **http://127.0.0.1/phpmyadmin** (or **http://localhost/phpmyadmin**).

```bash
curl -I http://127.0.0.1/phpmyadmin/
sudo apache2ctl -S
```

## 9. Git, GitHub CLI, GitLab CLI

Use Ubuntu packages and check their installed versions. Ubuntu package versions can lag upstream releases; use each vendor's official repository if upstream-latest is required.

```bash
sudo apt update
sudo apt install -y git gh glab

git --version
gh --version
glab --version
```

Optional: add the Git upstream PPA for newer Git builds (third-party repository; use only if needed):

```bash
# sudo add-apt-repository -y ppa:git-core/ppa
# sudo apt update && sudo apt install -y git
```

```bash
gh auth login
glab auth login
```

### Git identity

```bash
git config --global user.name '<YOUR_NAME>'
git config --global user.email '<YOUR_EMAIL>'
git config --global --list
```

### SSH authentication for GitLab (and optionally GitHub)

```bash
ssh-keygen -t ed25519 -C 'your-email@example.com'
eval "$(ssh-agent -s)"
ssh-add "$HOME/.ssh/id_ed25519"
cat "$HOME/.ssh/id_ed25519.pub"
```

Add the public key to your GitLab account, then test:

```bash
ssh -T git@gitlab.com
```

The first SSH connection may ask you to verify the host fingerprint. Compare it against GitLab's published fingerprint before accepting.

## 10. Persistent Bash history and `cls` shortcut

The following is idempotent: running it again replaces the same managed block rather than duplicating it. It keeps a large persistent history, appends instead of overwriting history between sessions, avoids storing commands prefixed with a space, and makes `cls` equivalent to `clear`.

```bash
sed -i '/^# BEGIN LOCAL DEV SHELL$/,/^# END LOCAL DEV SHELL$/d' "$HOME/.bashrc"
cat >> "$HOME/.bashrc" <<'EOF_SHELL'
# BEGIN LOCAL DEV SHELL
export HISTFILE="$HOME/.bash_history"
export HISTSIZE=10000
export HISTFILESIZE=200000
export HISTCONTROL=ignoreboth:erasedups
export HISTTIMEFORMAT='%F %T '
shopt -s histappend
PROMPT_COMMAND="history -a; history -n${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
alias cls='clear'
# END LOCAL DEV SHELL
EOF_SHELL
source "$HOME/.bashrc"
```

Test:

```bash
alias cls
cls
history 10
```

> [!NOTE]
> The original `HISTFILESIZE=0` does **not** mean unlimited history: it can truncate the history file to zero lines. Use a large positive number instead. Bash history is not a secure audit log; avoid typing secrets into commands.

## 11. Final verification checklist

```bash
printf '\n== OS ==\n'
lsb_release -a
printf '\n== PHP ==\n'
php -v
php -m | grep -Ei 'bcmath|curl|gd|intl|mbstring|mysqli|pdo_mysql|redis|zip|Zend OPcache'
printf '\n== Composer and Laravel ==\n'
composer --version
laravel --version
printf '\n== JavaScript ==\n'
node -v
npm -v
bun -v
printf '\n== Database ==\n'
mysql --version
mysql -u root -p -e 'SELECT VERSION(), CURRENT_USER();'
printf '\n== Web server ==\n'
apache2 -v
curl -I http://127.0.0.1/phpmyadmin/
printf '\n== Version control ==\n'
git --version
gh --version
glab --version
printf '\n== Services ==\n'
systemctl --no-pager --full status mysql php8.5-fpm apache2
```

Check listeners to ensure MySQL and Apache are not unexpectedly exposed:

```bash
sudo ss -lntp | grep -E ':(80|3306|33060)\b' || true
```

## 12. Updates and maintenance

```bash
sudo apt update && sudo apt full-upgrade -y
sudo apt autoremove -y
composer self-update --stable
composer global update
nvm install 24 --latest-npm
bun upgrade
```

`apt` only updates packages from repositories currently configured. Before changing major versions of PHP, Node.js, or MySQL, check Laravel/project compatibility and back up the databases.

## 13. Troubleshooting

| Symptom                                  | Check                                                                        |
| ---------------------------------------- | ---------------------------------------------------------------------------- | ------------ |
| `systemctl` fails in WSL                 | Enable systemd in `/etc/wsl.conf`, then `wsl --shutdown`                     |
| PHP module missing                       | `apt-cache policy php8.5-<module>` and `php -m`                              |
| Apache shows PHP source or downloads PHP | `sudo a2enconf php8.5-fpm`, `sudo a2enmod proxy_fcgi`, restart services      |
| phpMyAdmin prompts for credentials       | Confirm `conf.d` loading and server index; restart Apache/FPM                |
| phpMyAdmin connection denied             | Check MySQL root plugin/password and `127.0.0.1` TCP authentication          |
| `laravel` command not found              | Confirm `composer global config bin-dir --absolute` is in `PATH`             |
| `bun` or `nvm` missing                   | Start a new Bash shell or source `~/.bashrc`                                 |
| MySQL candidate is not 8.4               | Stop; configure a compatible official 8.4 source or use a verified container |
| Apache port 80 in use                    | `sudo ss -lntp                                                               | grep ':80 '` |

## Official documentation

- [Ubuntu packages](https://packages.ubuntu.com/)
- [Microsoft WSL installation](https://learn.microsoft.com/windows/wsl/install)
- [PHP documentation](https://www.php.net/manual/en/)
- [Composer](https://getcomposer.org/download/)
- [Laravel installation](https://laravel.com/docs/installation)
- [MySQL 8.4 APT installation](https://dev.mysql.com/doc/refman/8.4/en/linux-installation-apt-repo.html)
- [phpMyAdmin configuration](https://docs.phpmyadmin.net/en/latest/config.html)
- [nvm](https://github.com/nvm-sh/nvm)
- [Bun installation](https://bun.sh/docs/installation)
- [GitHub CLI](https://cli.github.com/)
- [GitLab CLI](https://gitlab.com/gitlab-org/cli)

---

**Scope:** Fresh Ubuntu 26.04 LTS / WSL2 development machines. Commands are documented installation steps, not a tested one-click installer. Validate repository availability, package versions, authentication, and service status on the actual machine before using the environment.
