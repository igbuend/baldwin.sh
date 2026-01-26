#!/usr/bin/env bash
export SHELL="/bin/bash"
export DOTNET_CLI_TELEMETRY_OPTOUT="1"
export HOMEBREW_NO_ANALYTICS=1
export JUST_HOME="$PWD"
export USERNAME=baldwin
export USER_UID=""
USER_UID=$(id -u)
export USER_GID=""
USER_GID=$(id -g)

echo "" | sudo tee -a /etc/hosts > /dev/null
echo "127.0.1.1 malpertus" | sudo tee -a /etc/hosts > /dev/null

sudo chown -R "$(whoami)":"$(whoami)" "$JUST_HOME"

# start docker
sudo service docker start

sudo apt update

if ! command -v pnpm >/dev/null 2>&1; then
  curl -fsSL https://get.pnpm.io/install.sh | sh -
fi
export PNPM_HOME="$HOME/.local/share/pnpm"
pnpm setup
touch "$HOME/.bashrc"

#shellcheck disable=SC1090,SC1091
source "$HOME/.bashrc"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac

# sarif-tools and strix-agent
pipx install sarif-tools strix-agent -qq && pipx ensurepath

# jsluice
go install github.com/BishopFox/jsluice/cmd/jsluice@latest

# gemini-cli
pnpm add -g @google/gemini-cli

sudo chown -R "$(whoami)":"$(whoami)" "$HOME"/.local

mkdir -p "$JUST_HOME"/{backup,bin,data,input,logs,notes,output,report,src,tmp}
mkdir -p "$JUST_HOME"/logs/script

# opengrep data

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
if cd "$JUST_HOME"/data; then
  sudo rm -rf "$JUST_HOME"/data/trailofbits-rules || true
  git clone --quiet --depth 1 https://github.com/trailofbits/semgrep-rules.git trailofbits-rules &>/dev/null
  if cd trailofbits-rules; then
    rm -rf .git
    rm -rf .github
    rm -rf .pre-commit-config.yaml
    rm -rf template.yaml
    find . -type f -not -iname "*.yaml" -delete
  fi
fi

sudo dotnet workload update
dotnet tool install --global Microsoft.CST.ApplicationInspector.CLI
sudo dotnet workload update

if [[ -d ".git" ]]; then
  git config --global --add safe.directory .
  pre-commit install
fi

# finalize and log currently installed standard tools
printf -v dt '%(%Y%m%d_%H%M%S)T\n' -1
export dt
export PATH=$PATH:/$HOME/.local/bin:/$HOME/.dotnet/tools # for sarif
mkdir -p "$JUST_HOME"/logs/dpkg
# shellcheck disable=SC2129 # fix later
echo "Microsoft Appinspector version: $(appinspector --version)" >> "$JUST_HOME"/logs/dpkg/"$dt"_dpkg.log
echo "Checkmarx KICS version: $(docker run --rm --quiet docker.io/checkmarx/kics:latest version)" >> "$JUST_HOME"/logs/dpkg/"$dt"_dpkg.log
echo "SARIF tools version: $(sarif --version)" >> "$JUST_HOME"/logs/dpkg/"$dt"_dpkg.log
echo "opengrep version: $(opengrep --version)" >> "$JUST_HOME"/logs/dpkg/"$dt"_dpkg.log
echo "Google osv-scanner version: $(docker run --rm --quiet ghcr.io/google/osv-scanner:latest --version | head -n 1)" >> "$JUST_HOME"/logs/dpkg/"$dt"_dpkg.log
echo "" >> "$JUST_HOME"/logs/dpkg/"$dt"_dpkg.log
dpkg -l >> "$JUST_HOME"/logs/dpkg/"$dt"_dpkg.log

# implement terminal input logging
mkdir -p "$JUST_HOME"/logs/script/
# shellcheck disable=SC2016
echo '[[ "$SHLVL" -eq 2 ]] && '"mkdir -p $JUST_HOME"/logs/script/' && safe_dt=$(date --utc --rfc-3339=ns)'>> "$HOME"/.bashrc
# shellcheck disable=SC2016
echo '[[ "$SHLVL" -eq 2 ]] && '"script --quiet $JUST_HOME"/logs/script/'"$safe_dt"_script.log' >> "$HOME"/.bashrc
exit 0
