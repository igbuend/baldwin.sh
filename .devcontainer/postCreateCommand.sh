#!/usr/bin/env bash
export SHELL="/bin/bash"
export DOTNET_CLI_TELEMETRY_OPTOUT="1"
export JUST_HOME="$PWD"
export USERNAME=baldwin
export USER_UID=""
USER_UID=$(id -u)
export USER_GID=""
USER_GID=$(id -g)

echo "127.0.1.1 malpertus" | sudo tee -a /etc/hosts > /dev/null

sudo chown -R "$(whoami)":"$(whoami)" "$JUST_HOME"

# start docker
sudo service docker start

sudo apt update
pnpm setup
sudo pnpm self-update
export PNPM_HOME="$HOME/.local/share/pnpm"
touch "$HOME/.bashrc"
#shellcheck disable=SC1090,SC1091
source "$HOME/.bashrc"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
sudo chown -R "$(whoami)":"$(whoami)" "$HOME"/.local

pnpm add -g @cyclonedx/cdxgen retire @google/gemini-cli

# shellcheck disable=SC2102
pipx install sarif-tools
pipx ensurepath

mkdir -p "$JUST_HOME"/{backup,bin,data,input,logs,notes,output,report,src,tmp}
mkdir -p "$JUST_HOME"/logs/{appinspector,dpkg,script}
mkdir -p "$JUST_HOME"/output/{appinspector,cloc,depscan,kics,opengrep,osv,sarif,sha256,unpack}

# opengrep
# alternative for version: git -c 'versionsort.suffix=-' ls-remote --tags --sort='v:refname' https://github.com/opengrep/opengrep.git | tail --lines=1 | cut --delimiter='/' --fields=3
og_version=$(curl -s https://api.github.com/repos/opengrep/opengrep/releases/latest | grep -oP '"tag_name": "\K(.*)(?=")')
if [[ -n "$og_version" ]]; then
  if [[ "$arch" == *arm* ]]; then
    sudo wget --quiet --output-document /usr/local/bin/opengrep https://github.com/opengrep/opengrep/releases/download/"$og_version"/opengrep_manylinux_aarch64
  else
    sudo wget --quiet --output-document /usr/local/bin/opengrep https://github.com/opengrep/opengrep/releases/download/"$og_version"/opengrep_manylinux_x86
  fi
  sudo chmod a+x /usr/local/bin/opengrep || true
  if cd "$JUST_HOME"/data; then
    sudo rm -rf ./opengrep-rules || true
    git clone --depth 1 https://github.com/opengrep/opengrep-rules.git
    if cd opengrep-rules; then # https://unicolet.blogspot.com/2025/04/opengrep-quickstart.html
      rm -rf .git
      rm -rf .github
      rm -rf .pre-commit-config.yaml
      rm -rf template.yaml
      find . -type f -not -iname "*.yaml" -delete
    fi
  fi
fi

# todo.sh
if cd "$JUST_HOME"/tmp; then
  sudo rm -rf ./todo.txt-cli || true
  git clone --depth 1 https://github.com/todotxt/todo.txt-cli.git
  if cd todo.txt-cli; then
    sudo make install
    cd ..
  fi
  sudo rm -rf ./todo.txt-cli || true
fi
mkdir -p "$JUST_HOME/data/todo"
export TODO_DIR="$JUST_HOME/data/todo"
echo 'export TODO_DIR="/workspaces/baldwin/data/todo"' >> "$HOME/.bashrc"

# jsluice
go install github.com/BishopFox/jsluice/cmd/jsluice@latest

arch=$(uname -m)
if [[ "$arch" == *arm* ]]; then
  sudo wget --quiet --output-document /usr/local/bin/osv-scanner https://github.com/google/osv-scanner/releases/latest/download/osv-scanner_linux_arm64
else
  sudo wget --quiet --output-document /usr/local/bin/osv-scanner https://github.com/google/osv-scanner/releases/latest/download/osv-scanner_linux_amd64
fi
sudo chmod a+x /usr/local/bin/osv-scanner || true

sudo dotnet workload update
dotnet tool install --global Microsoft.CST.ApplicationInspector.CLI
sudo dotnet workload update

if [[ -d ".git" ]]; then
  git config --global --add safe.directory .
  pre-commit install
fi

# finalize and log currently installed standard tools
# truffelhog gives error when trying to run as non-root docker :(
printf -v dt '%(%Y-%m-%d %H:%M:%S)T\n' -1
export dt
export PATH=$PATH:/$HOME/.local/bin:/$HOME/.dotnet/tools # for depscan and sarif
# shellcheck disable=SC2129 # fix later
echo "Microsoft Appinspector version: $(appinspector --version)" >> "$JUST_HOME"/logs/dpkg/"$dt"_dpkg.log
echo "Checkmarx KICS version: $(docker run docker.io/checkmarx/kics:latest version)" >> "$JUST_HOME"/logs/dpkg/"$dt"_dpkg.log
echo "OWASP dep-scan version: $(docker run --quiet --rm ghcr.io/owasp-dep-scan/dep-scan depscan --version)" >> "$JUST_HOME"/logs/dpkg/"$dt"_dpkg.log
echo "SARIF tools version: $(sarif --version)" >> "$JUST_HOME"/logs/dpkg/"$dt"_dpkg.log
echo "opengrep version: $(opengrep --version)" >> "$JUST_HOME"/logs/dpkg/"$dt"_dpkg.log
echo "Google osv-scanner version: $(osv-scanner --version | head -n 1)" >> "$JUST_HOME"/logs/dpkg/"$dt"_dpkg.log
# echo "Trufflesecurity truffelhog version: $(docker run -u "$USER_UID":"$USER_GID" docker.io/trufflesecurity/trufflehog:latest --version)" >> "$JUST_HOME"/logs/dpkg/"$dt"_dpkg.log
echo "Trufflesecurity truffelhog version: $(docker run docker.io/trufflesecurity/trufflehog:latest --version)" >> "$JUST_HOME"/logs/dpkg/"$dt"_dpkg.log
echo "" >> "$JUST_HOME"/logs/dpkg/"$dt"_dpkg.log
dpkg -l >> "$JUST_HOME"/logs/dpkg/"$dt"_dpkg.log

# implement terminal input logging
# shellcheck disable=SC2016
echo '[[ "$SHLVL" -eq 2 ]] && dt=$(date --utc --rfc-3339=ns)'>> "$HOME/.bashrc"
# shellcheck disable=SC2016
echo '[[ "$SHLVL" -eq 2 ]] && '"script --quiet $JUST_HOME"/logs/script/'"$dt"_script.log' >> "$HOME/.bashrc"
exit 0
