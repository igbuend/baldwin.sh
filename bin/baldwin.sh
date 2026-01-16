#!/usr/bin/env bash

# ------ Variables ------
HOST_NAME="$(hostname)"
readonly HOST_NAME
progname="$(basename "$0")"
readonly progname

# ------ Helper Functions ------

# displays an error message and exit
die() {
  echo ""
  echo "$HOST_NAME $progname  Error: $1" >&2
  echo ""
  exit 1
}

# usage function
usage(){
  cat << HEREDOC

  Usage: $progname --output <path>

  mandatory arguments:
    -o, --output <path>     folder to be created, containing the "justfile"

  optional arguments:
    -h, --help              show this help message and exit

HEREDOC
}

# --- Main Script ---

# ------ Argument Parsing ------

# bail if no params

[ $# -eq 0 ] && usage && exit 1

# use getopt and store the output into $OPTS
# note the use of -o for the short options, --long for the long name options
# and a : for any option that takes a parameter

if ! OPTS=$(getopt --options="o:h" --longoptions="help,output:" --name "$progname" -- "$@"); then
   echo "Error in command line arguments." >&2 ; usage; exit 1 ;
fi

eval set -- "$OPTS"
while true; do
  case "$1" in
    -h | --help ) usage; exit 0 ;;
    -o | --output ) output_folder="$2"; shift 2 ;;
    -- ) shift; break ;;
    * ) break ;;
  esac
done

shift "$(( OPTIND - 1 ))"
if [ -z "$output_folder" ]; then
  die "Missing -o/--output parameter Use --help for usage."
fi

if [ -d "$output_folder" ]; then
  die "Output folder already already exists. Please choose another location."
fi

mkdir -p "$output_folder"/{backup,bin,data,input,logs,output,src,tmp} &>/dev/null || true

# check if output_ folder exists and is writeable
if [ ! -d "$output_folder" ]; then
  die "Source folder '$output_folder' does not exist or is not a directory."
else
  realpath_folder=$(realpath "$output_folder")
  if [ ! -w "$realpath_folder" ]; then
    die "Output folder '$output_folder' is not writable."
  fi
fi
#shellcheck disable=SC1039
cat > "$realpath_folder"/justfile << 'EOF'
#!/usr/bin/env just --justfile
# shellcheck disable=SC1083,SC2148
alias checksum := sha256
alias inspect := appinspector
alias loc := cloc
alias osv := osv-scanner
alias sarif_tools := csv
alias secrets := gitleaks
# read .env file with variables
set dotenv-load := true
# default, just list recipes
default:
  @just --list
# creates a backup of everything (except /data and /tmp) in '/backup'
backup: (_fix_deps "basename,bzip2,cp,echo,mkdir,mktemp,pbzip2,printf,rm,tar")
  #!/usr/bin/env bash
  set -euo pipefail
  JUST_HOME="$PWD" && \
    JUST_BASE="${JUST_HOME##*/}" && \
    HOST_NAME="$(hostname)" && \
    progname="$(basename "$0")" && \
    printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && \
    printf -v safe_dt '%(%Y%m%d_%H%M%S)T' -1 && \
    echo "$dt [$HOST_NAME] [$progname] Start full backup (except /data and /tmp folders)."
  mkdir -p "$JUST_HOME"/{backup,tmp} && \
    tempfolder=$(mktemp -d "$JUST_HOME/tmp/XXXXXX") && \
    echo "    [01/04] Created work folders."
  tar -C "$JUST_HOME" --use-compress-program="pbzip2" \
    --create \
    -f "$tempfolder"/"$safe_dt"_"$JUST_BASE"_scr_backup.tar.bz2 \
    --exclude=data \
    --exclude=backup \
    --exclude=tmp . 1>/dev/null \
    && echo "    [02/04] Created backup archive."
  cp "$tempfolder"/"$safe_dt"_"$JUST_BASE"_scr_backup.tar.bz2 "$JUST_HOME"/backup/ \
    && rm "$tempfolder"/"$safe_dt"_"$JUST_BASE"_scr_backup.tar.bz2 \
    && echo "    [03/04] Moved archive to /archive folder."
  rm -rf "$tempfolder" || true
  if bzip2 --test "$JUST_HOME"/backup/"$safe_dt"_"$JUST_BASE"_scr_backup.tar.bz2 &>/dev/null; then
    echo "    [04/04] Archive tested as valid .bz2 archive."
    confirm="Backup is /backup/"$safe_dt"_"$JUST_BASE"_scr_backup.tar.bz2."
    exit_code=0
  else
    echo "    [04/04] Archive failed test!!! Not a valid .bz2 archive!!!"
    confirm="Failed backup, please review problem and try again!"
    exit_code=1
  fi
  printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && echo "$dt [$HOST_NAME] [$progname] End run. $confirm"
  exit "$exit_code"
# creates a backup of only the '/output' folder in '/backup'
output: (_fix_deps "basename,bzip2,cp,echo,mkdir,mktemp,pbzip2,printf,rm,tar")
  #!/usr/bin/env bash
  set -euo pipefail
  JUST_HOME="$PWD" && \
    JUST_BASE="${JUST_HOME##*/}" && \
    HOST_NAME="$(hostname)" && \
    progname="$(basename "$0")" && \
    printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && \
    printf -v safe_dt '%(%Y%m%d_%H%M%S)T' -1 && \
    echo "$dt [$HOST_NAME] [$progname] Start backing up the 'output' directory."
  mkdir -p "$JUST_HOME"/{tmp,backup,output} && \
    tempfolder=$(mktemp -d "$JUST_HOME/tmp/XXXXXX") && \
    echo "    [01/04] Created work folders."
  tar -C "$JUST_HOME" --use-compress-program="pbzip2" -cf "$tempfolder"/"$safe_dt"_"$JUST_BASE"_scr_output.tar.bz2 output && \
    echo "    [02/04] Created archive in temporary folder."
  cp "$tempfolder"/"$safe_dt"_"$JUST_BASE"_scr_output.tar.bz2 "$JUST_HOME"/backup/ && \
    rm "$tempfolder"/"$safe_dt"_"$JUST_BASE"_scr_output.tar.bz2 && \
    echo "    [03/04] Moved archive to 'backup' folder."
  rm -rf "$tempfolder" &>/dev/null || true
  if bzip2 --test "$JUST_HOME"/backup/"$safe_dt"_"$JUST_BASE"_scr_output.tar.bz2 &>/dev/null; then
    echo "    [04/04] Archive tested as valid .bz2 archive."
    confirm="Backup is /backup/"$safe_dt"_"$JUST_BASE"_scr_output.tar.bz2."
    exit_code=0
  else
    echo "    [04/04] Archive failed test!!! Not a valid .bz2 archive!!!"
    confirm="Failed backup, please review problem and try again!"
    exit_code=1
  fi
  printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && echo "$dt [$HOST_NAME] [$progname] End backup of /output. $confirm"
  exit "$exit_code"
# validates and installs necessary tools for Ubuntu LTS
_fix_deps DEPS="apt,command,compgen,echo,mkdir,printf,sudo,true,xargs":
  #!/usr/bin/env bash
  # to fix broken Ubuntu installations at client.
  set -euo pipefail
  JUST_HOME="$PWD" && \
    HOST_NAME="$(hostname)" && \
    progname="$(basename "$0")" && \
    printf -v dt '%(%Y%m%d_%H%M%S)T' -1 && \
    echo "$dt [$HOST_NAME] [$progname] Start dependency validation and installation."
  mkdir -p "$JUST_HOME"/logs/fix_deps && echo "    [01/07] Created work folders."

  bash_builtins=($(compgen -b))

  # Ubuntu package mapping for common dependencies
  declare -A ubuntu_packages=(
    ["asciinema"]="asciinema"
    ["basename"]="coreutils"
    ["bats"]="bats"
    ["bc"]="bc"
    ["build-essential"]="build-essential"
    ["bzip2"]="bzip2"
    ["cat"]="coreutils"
    ["ca-certificates"]="ca-certificates"
    ["coreutils"]="coreutils"
    ["cp"]="coreutils"
    ["cron"]="cron"
    ["chmod"]="coreutils"
    ["chown"]="coreutils"
    ["cloc"]="cloc"
    ["cp"]="coreutils"
    ["curl"]="curl"
    ["cut"]="coreutils"
    ["date"]="coreutils"
    ["df"]="coreutils"
    ["dialog"]="dialog"
    ["dir"]="coreutils"
    ["dirmngr"]="dirmngr"
    ["dnsutils"]="dnsutils"
    ["dos2unix"]="dos2unix"
    ["dotnet-sdk-8.0"]="dotnet-sdk-8.0"
    ["du"]="coreutils"
    ["echo"]="coreutils"
    ["false"]="coreutils"
    ["fuse-overlayfs"]="fuse-overlayfs"
    ["gcc"]="gcc"
    ["gh"]="gh"
    ["git"]="git"
    ["gawk"]="gawk"
    ["gnupg2"]="gnupg2"
    ["golang"]="golang-go"
    ["go"]="golang-go"
    ["jq"]="jq"
    ["ln"]="coreutis"
    ["locales"]="locales"
    ["ls"]="coreutils"
    ["lsb-release"]="lsb-release"
    ["make"]="make"
    ["mktemp"]="coreutils"
    ["mv"]="coreutils"
    ["mkdir"]="coreutils"
    ["net-tools"]="net-tools"
    ["node"]="nodejs"
    ["nmap"]="nmap"
    ["npm"]="npm"
    ["passt"]="passt"
    ["pbzip2"]="pbzip2"
    ["pkg-config"]="pkg-config"
    ["pnpm"]="pnpm"
    ["pigz"]="pigz"
    ["pipx"]="pipx"
    ["pre-commit"]="pre-commit"
    ["printf"]="coreutils"
    ["pwd"]="coreutils"
    ["python3"]="python3"
    ["python3-pip"]="python3-pip"
    ["python3-venv"]="python3-venv"
    ["ripgrep"]="ripgrep"
    ["rm"]="coreutils"
    ["rmdir"]="coreutils"
    ["shellcheck"]="shellcheck"
    ["shuff"]="coreutils"
    ["slirp4netns"]="slirp4netns"
    ["tar"]="tar"
    ["tee"]="coreutils"
    ["touch"]="coreutils"
    ["tr"]="coreutils"
    ["tree"]="tree"
    ["true"]="coreutils"
    ["unzip"]="unzip"
    ["uidmap"]="uidmap"
    ["uniq"]="coreutils"
    ["wc"]="coreutils"
    ["wget"]="wget"
    ["whoami"]="coreutils"
    ["xargs"]="findutils"
    ["yq"]="yq"
    ["zip"]="zip"
    ["7z"]="p7zip-full"
  )

  deps={{DEPS}}

  echo "    [02/07] Parsing dependency list..."
  echo "      📦 Dependencies to validate: $deps"
  echo "    [03/07] Checking each dependency..."

  found_builtins=()
  found_path=()
  to_install=()
  unknown_to_install=()

  IFS=',' read -ra deps_array <<< "$deps"

  for dep in "${deps_array[@]}"; do
    # Remove whitespace and quotes
    dep=$(echo "$dep" | xargs)
    if [ -z "$dep" ]; then
      continue
    fi

    # Check if it is a bash builtin
    if [[ " ${bash_builtins[*]} " =~ " ${dep} " ]]; then
      echo "      ✅ $dep - built into bash shell"
      found_builtins+=("$dep")
      continue
    else
      # Check if command exists in path
      if command -v "$dep" >/dev/null 2>&1; then
        echo "      ✅ $dep - found in path"
        found_path+=("$dep")
      else
        # echo "      ⚠️   $dep - not found in path"
        # Check if it's a Ubuntu package that might not be in PATH
        pkg="${ubuntu_packages[$dep]:-$dep}"
        if dpkg -l | grep -q "^ii  $pkg "; then
          echo "      ✅ $dep - installed as Ubuntu package '$pkg'"
        else
          # If we get here, it's missing
          echo "      ❌ $dep - missing"
          if [[ -n "${ubuntu_packages[$dep]:-}" ]]; then
            to_install+=("${ubuntu_packages[$dep]:-$dep}")
          else
            unknown_to_install+="$dep"
          fi
        fi
      fi
    fi
  done

  echo "    [04/07] Dependency check summary:"
  echo "      📋 Found bash builtins: ${#found_builtins[@]}"
  echo "      📋 Found in path: ${#found_path[@]}"
  echo "      📋 Missing known packages: ${#to_install[@]}"
  echo "      📋 Missing unknown packages: ${#unknown_to_install[@]}"

  if [ ${#to_install[@]} -gt 0 ] || [ ${#unknown_to_install[@]} -gt 0 ]  ; then
    echo "    [05/07] Installing missing packages..."

    if ! sudo -n true 2>/dev/null; then
      echo "    ❌ Error: Cannot install packages - sudo access required"
      echo "    Please run 'sudo apt update && sudo apt install ${to_install[*]}' manually"
      exit 1
    fi

    if ! sudo apt update -y &>/dev/null; then
      echo "    ❌ Error: Failed to update package lists"
      exit 1
    fi

    if [ ${#to_install[@]} -gt 0 ] ; then
      echo "      📦 Known packages to install: ${to_install[*]}"
      if ! sudo apt install -y "${to_install[@]}"; then
        echo "  ❌ Error: Failed to install packages"
        echo "  Attempt to install manually: sudo apt install -y ${to_install[*]}"
        exit 1
      else
        echo "  ✅ Successfully installed: ${to_install[*]}"
      fi
    fi

    if [ ${#unknown_to_install[@]} -gt 0 ] ; then
      echo "      📦 Unknown packages to install: ${unknown_to_install[*]}"
      if ! sudo apt install -y "${unknown_to_install[@]}" &>/dev/null; then
        echo "      ❌ Error: Failed to install packages"
        echo "      Please attempt to install manually: sudo apt install -y ${unknown_to_install[*]}"
        exit 1
      else
          echo "  ✅ Successfully installed: ${unknown_to_install[*]}"
      fi
    fi
  else
    echo "    [05/07] All packages already installed."
  fi

  echo "    [06/07] Final verification..."
  final_missing=()
  for dep in "${deps_array[@]}"; do
    dep=$(echo "$dep" | xargs)
    if [ -z "$dep" ]; then
      continue
    fi

    if ! command -v "$dep" >/dev/null 2>&1 && ! [[ " ${bash_builtins[*]} " =~ " ${dep} " ]]; then
      final_missing+=("$dep")
    fi
  done

  if [ ${#final_missing[@]} -eq 0 ]; then
    echo "      🎉 All dependencies validated successfully!"
    exit_code=0
  else
    echo "      ❌ Still missing: ${final_missing[*]}"
    echo "      Please install these dependencies manually and try again."
    exit_code=1
  fi

  echo "    [07/07] Creating dependency report..."

  {
    echo "Dependency Validation Report - $dt"
    echo "=================================="
    echo "Checked: ${deps_array[*]}"
    echo "Found bash builtins: ${found_builtins[*]}"
    echo "Installed known Ubuntu packages: ${to_install[*]}"
    echo "Still missing: ${final_missing[*]}"
    echo "Exit code: $exit_code"
  } > "$JUST_HOME/logs/fix_deps/${dt}_fixdeps.log"

  printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1
  if [ $exit_code -eq 0 ]; then
    echo "$dt [$HOST_NAME] [$progname] End run. All dependencies validated successfully."
  else
    echo "$dt [$HOST_NAME] [$progname] End run. Some dependencies are still missing."
  fi
  exit $exit_code
# empties all folders except '/data' and '/backup' folders
clean:
  #!/usr/bin/env bash
  set -euo pipefail
  JUST_HOME="$PWD" && HOST_NAME="$(hostname)" && progname="$(basename "$0")" && printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && echo "$dt [$HOST_NAME] [$progname] Start emptying all folders (not including 'data' and 'backup')."
  mkdir -p "$JUST_HOME"/{input,logs,notes,output,report,src,tmp} && echo "    [01/08] Created work folders."
  find "$JUST_HOME"/input -mindepth 1 -delete &>/dev/null && echo "    [02/08] Deleted all files in $JUST_HOME/input/."
  find "$JUST_HOME"/notes -mindepth 1 -delete &>/dev/null && echo "    [03/08] Deleted all files in $JUST_HOME/notes/."
  find "$JUST_HOME"/output -mindepth 1 -delete &>/dev/null && echo "    [04/08] Deleted all files in $JUST_HOME/output/."
  find "$JUST_HOME"/report -mindepth 1 -delete &>/dev/null && echo "    [05/08] Deleted all files in $JUST_HOME/report/."
  find "$JUST_HOME"/src -mindepth 1 -delete &>/dev/null && echo "    [06/08] Deleted all files in $JUST_HOME/src/."
  find "$JUST_HOME"/tmp -mindepth 1 -delete &>/dev/null && echo "    [07/08] Deleted all files in $JUST_HOME/tmp/."
  find "$JUST_HOME"/logs -mindepth 1 -delete &>/dev/null && echo "    [08/08] Deleted all files in $JUST_HOME/logs/."
  printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && echo "$dt [$HOST_NAME] [$progname] End run."
  # mkdir -p "$JUST_HOME"/logs/script && script --quiet "$JUST_HOME"/logs/script/"$dt"_script.log # restart terminal logging, kludge: increases $SHLVL
# empties all folders including data and backup folders
empty:
  #!/usr/bin/env bash
  set -euo pipefail
  JUST_HOME="$PWD" && HOST_NAME="$(hostname)" &&
    progname="$(basename "$0")" && \
    printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && \
    echo "$dt [$HOST_NAME] [$progname] Start emptying all folders (including 'data' and 'backup')."
  mkdir -p "$JUST_HOME"/{backup,data,input,logs,notes,output,report,src,tmp} && echo "    [01/10] Created work folders."
  find "$JUST_HOME"/backup -mindepth 1 -delete &>/dev/null && echo "    [02/10] Deleted all files in $JUST_HOME/backup/."
  find "$JUST_HOME"/data -mindepth 1 -delete &>/dev/null && echo "    [03/10] Deleted all files in $JUST_HOME/data/."
  find "$JUST_HOME"/input -mindepth 1 -delete &>/dev/null && echo "    [04/10] Deleted all files in $JUST_HOME/input/."
  find "$JUST_HOME"/notes -mindepth 1 -delete &>/dev/null && echo "    [05/10] Deleted all files in $JUST_HOME/notes/."
  find "$JUST_HOME"/output -mindepth 1 -delete &>/dev/null && echo "    [06/10] Deleted all files in $JUST_HOME/output/."
  find "$JUST_HOME"/report -mindepth 1 -delete &>/dev/null && echo "    [07/10] Deleted all files in $JUST_HOME/report/."
  find "$JUST_HOME"/src -mindepth 1 -delete &>/dev/null && echo "    [08/10] Deleted all files in $JUST_HOME/src/."
  find "$JUST_HOME"/tmp -mindepth 1 -delete &>/dev/null && echo "    [09/10] Deleted all files in $JUST_HOME/tmp/."
  find "$JUST_HOME"/logs -mindepth 1 -delete &>/dev/null && echo "    [10/10] Deleted all files in $JUST_HOME/logs/."
  printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && echo "$dt [$HOST_NAME] [$progname] End run."
# runs everything, after upgrading Ubuntu and all tools
do_fresh:
  just upgrade
  just doit
# runs everything, without upgrading Ubuntu or other tools
doit:
  just _fix_deps
  just sha256
  just unpack
  just cloc
  just appinspector
  just osv-scanner
  just kics
  just gitleaks
  just opengrep
  just noir
  just csv
# installs Google gemini-cli and usefull extensions if not yet installed
_gemini-pnpm:
  #!/usr/bin/env bash
  set -euo pipefail
  JUST_HOME="$PWD" && \
    HOST_NAME="$(hostname)" && \
    progname="$(basename "$0")" && \
    printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && \
    echo "$dt [$HOST_NAME] [$progname] Check installation of 'Google gemini-cli'."
  if ! command -v gemini >/dev/null 2>&1; then
    if ! [ -d "$JUST_HOME/logs/gemini/" ] ; then
      mkdir -p "$JUST_HOME"/logs/gemini
    fi
    printf -v safe_dt '%(%Y%m%d_%H%M%S)T' -1
    pnpm add -g @google/gemini-cli &> "$JUST_HOME"/logs/gemini/"$safe_dt"_gemini_installation.log
  fi
  extensions=$(gemini extensions list)
  if [[ "$extensions" == *"gemini-cli-security"* ]]; then
    echo "  + Found extension 'gemini-cli-security'"
  else
    echo "  + Installing extension 'gemini-cli-security'"
    gemini extensions install https://github.com/gemini-cli-extensions/security --consent &> "$JUST_HOME"/logs/gemini/"$safe_dt"_gemini-cli-security_installation.log
  fi
  if [[ "$extensions" == *"code-review"* ]]; then
    echo "  + Found extension 'code-review'"
  else
    echo "  + Installing extension 'code-review'"
    gemini extensions install https://github.com/gemini-cli-extensions/code-review --consent &> "$JUST_HOME"/logs/gemini/"$safe_dt"_gemini-cli-code-review_installation.log
  fi
  if [[ "$extensions" == *"conductor"* ]]; then
    echo "  + Found extension 'conductor'"
  else
    echo "  + Installing extension 'conductor'"
    gemini extensions install https://github.com/gemini-cli-extensions/conductor --consent &> "$JUST_HOME"/logs/gemini/"$safe_dt"_gemini-cli-conductor_installation.log
  fi
  gemini_version=$(gemini --version)
  printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && echo "$dt [$HOST_NAME] [$progname] Finished setting up 'gemini-cli' ($gemini_version)."
# opens Google gemini-cli
gemini: _gemini-pnpm
  #!/usr/bin/env bash
  set -euo pipefail
  JUST_HOME="$PWD" && \
    HOST_NAME="$(hostname)" && \
    progname="$(basename "$0")" && \
    printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && \
    echo "$dt [$HOST_NAME] [$progname] Start interactive session with 'Google gemini-cli'."
  gemini
  gemini_version=$(gemini --version)
  printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && echo "$dt [$HOST_NAME] [$progname] End run 'gemini-cli' ($gemini_version)."
# upgrades Ubuntu and all seperately installed tools
upgrade: _homebrew
  #!/usr/bin/env bash
  set -euo pipefail
  JUST_HOME="$PWD" && \
    HOST_NAME="$(hostname)" && \
    progname="$(basename "$0")" && \
    printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && \
    echo "$dt [$HOST_NAME] [$progname] Start update required tools."
  mkdir -p "$JUST_HOME"/logs/dpkg
  if sudo -n true 2>/dev/null; then
    echo "user can run passwordless sudo"
  else
    echo "  !!! user cannot run passwordless sudo"
  fi
  sudo apt update -y && sudo apt upgrade -y
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" && brew update && brew outdated && brew upgrade && brew cleanup
  pipx upgrade-all
  arch=$(uname -m)
  if [[ "$arch" == *arm* ]]; then
    sudo wget --quiet --output-document /usr/local/bin/osv-scanner https://github.com/google/osv-scanner/releases/latest/download/osv-scanner_linux_arm64
  else
    sudo wget --quiet --output-document /usr/local/bin/osv-scanner https://github.com/google/osv-scanner/releases/latest/download/osv-scanner_linux_amd64
  fi
  sudo chmod a+x /usr/local/bin/osv-scanner || true
  og_version=$(curl -s https://api.github.com/repos/opengrep/opengrep/releases/latest | grep -oP '"tag_name": "\K(.*)(?=")')
  if [[ -n "$og_version" ]]; then
    if [[ "$arch" == *arm* ]]; then
      sudo wget --quiet --output-document /usr/local/bin/opengrep https://github.com/opengrep/opengrep/releases/download/"$og_version"/opengrep_manylinux_aarch64
    else
      sudo wget --quiet --output-document /usr/local/bin/opengrep https://github.com/opengrep/opengrep/releases/download/"$og_version"/opengrep_manylinux_x86
    fi
    sudo chmod a+x /usr/local/bin/opengrep || true
    mkdir -p "$JUST_HOME"/data
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
  dotnet tool update --global Microsoft.CST.ApplicationInspector.CLI
  # pnpm update
  gemini extensions update --all
  printf -v safe_dt '%(%Y%m%d_%H%M%S)T' -1
  mkdir -p "$JUST_HOME"/logs/dpkg
  dpkg -l > "$JUST_HOME"/logs/dpkg/"$safe_dt"_dpkg.log
  printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && echo "$dt [$HOST_NAME] [$progname] End run."
# Verifies installation of  Microsoft AppInspector
_appinspector-install:
  #!/usr/bin/env bash
  set -euo pipefail
  JUST_HOME="$PWD" && \
    HOST_NAME="$(hostname)" && \
    progname="$(basename "$0")" && \
    printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && \
    echo "$dt [$HOST_NAME] [$progname] Check installation of 'Microsoft AppInspector'."
  if ! [ -d "$JUST_HOME/logs/appinspector/" ] ; then
    mkdir -p "$JUST_HOME"/logs/appinspector
  fi
  if ! command -v dotnet >/dev/null 2>&1; then
    echo "  !!! dotnet not installed (will never happen, but I have a cat). Try installing it with 'just _dotnet'."
  else
    if ! command -v appinspector >/dev/null 2>&1; then
      printf -v safe_dt '%(%Y%m%d_%H%M%S)T' -1
      echo "hello"
      dotnet tool install --global Microsoft.CST.ApplicationInspector.CLI  &> "$JUST_HOME"/logs/appinspector/"$safe_dt"_dotnet_appinspector_installation.log
    fi
  fi
  appinspector_version=$(appinspector --version || true)
  printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && echo "$dt [$HOST_NAME] [$progname] Finished checking installation of 'Microsoft Appinspector' ($appinspector_version)."
# analyses technology with AppInspector tool over sources in '/src'
appinspector: _appinspector-install
  #!/usr/bin/env bash
  set -euo pipefail
  JUST_HOME="$PWD" && \
    HOST_NAME="$(hostname)" && \
    progname="$(basename "$0")" && \
    printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && \
    printf -v dafe_dt '%(%Y%m%d_%H%M%S)T' -1 && \
    echo "$dt [$HOST_NAME] [$progname] Start run."
  mkdir -p "$JUST_HOME"/output/{appinspector,sarif} && mkdir -p "$JUST_HOME"/logs/appinspector && mkdir -p "$JUST_HOME"/src/ && echo "    [01/04] Created work folders."
  if [ -d "$JUST_HOME/src/" ] && [ "$(ls -A "$JUST_HOME/src/")" ]; then
    echo "    [02/06] Running AppInspector (HTML)..."
    if appinspector analyze --single-threaded --file-timeout 500000 --disable-archive-crawling --log-file-path "$JUST_HOME"/logs/appinspector/"$safe_dt"_appinspector_html.log --log-file-level Information --output-file-path "$JUST_HOME"/output/appinspector/"$safe_dt"_appinspector.html --output-file-format html --no-show-progress -s "$JUST_HOME"/src/ 2>&1 | tee -a "$JUST_HOME"/logs/appinspector/"$safe_dt"_appinspector_html.log >/dev/null; then
      echo "    [02/06] AppInspector HTML output completed successfully."
    else
      echo "  !!! WARNING: AppInspector HTML output completed with errors. Check $JUST_HOME/logs/appinspector/"$safe_dt"_appinspector_html.log"
    fi
    echo "    [03/06] Running AppInspector (SARIF)..."
    if appinspector analyze --file-timeout 500000 --disable-archive-crawling --log-file-path "$JUST_HOME"/logs/appinspector/"$safe_dt"_appinspector_sarif.log --log-file-level Information --output-file-path "$JUST_HOME"/output/appinspector/"$safe_dt"_appinspector.sarif --output-file-format sarif --no-show-progress -s "$JUST_HOME"/src/ 2>&1 | tee -a "$JUST_HOME"/logs/appinspector/"$safe_dt"_appinspector_sarif.log >/dev/null; then
      echo "    [03/06] AppInspector SARIF output completed successfully."
    else
      echo "  !!! WARNING: AppInspector SARIF output completed with errors. Check $JUST_HOME/logs/appinspector/"$safe_dt"_appinspector_sarif.log"
    fi
    if [ ! -f "$JUST_HOME"/output/appinspector/"$safe_dt"_appinspector.sarif ]; then
      echo "  !!! ERROR: AppInspector did not create SARIF output file."
      printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && echo "$dt [$HOST_NAME] [$progname] End run with ERROR - no SARIF output."
      exit 1
    fi
    echo "    [04/06] Running AppInspector (TXT)..."
    if appinspector analyze --file-timeout 500000 --disable-archive-crawling --log-file-path "$JUST_HOME"/logs/appinspector/"$safe_dt"_appinspector_text.log --no-file-metadata --log-file-level Information --output-file-path "$JUST_HOME"/output/appinspector/"$safe_dt"_appinspector.text --output-file-format text --no-show-progress -s "$JUST_HOME"/src/ 2>&1 | tee -a "$JUST_HOME"/logs/appinspector/"$safe_dt"_appinspector_text.log >/dev/null; then
      echo "    [04/06] AppInspector TXT output completed successfully."
    else
      echo "  !!! WARNING: AppInspector TXT output completed with errors. Check $JUST_HOME/logs/appinspector/"$safe_dt"_appinspector_text.log"
    fi
    rm -f "$JUST_HOME"/output/sarif/*appinspector.sarif 2>/dev/null || true
    echo "    [05/06] Removed earlier APPINSPECTOR SARIF output from '/output/sarif' folder."
    cp "$JUST_HOME"/output/appinspector/"$saf_dt"_appinspector.sarif "$JUST_HOME"/output/sarif/"$safe_dt"_appinspector.sarif && echo "    [06/06] Copied SARIF output to '/output/sarif' folder."
  else
    echo "  !!! ERROR: The source code folder is empty. Please unpack the sources with 'just unpack'."
    printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && echo "$dt [$HOST_NAME] [$progname] End run with ERROR - no source code."
    exit 1
  fi
  printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && echo "$dt [$HOST_NAME] [$progname] End run."
# show Lines of Code (LOC) for sources in '/src'
cloc:
  #!/usr/bin/env bash
  set -euo pipefail
  JUST_HOME="$PWD" && HOST_NAME="$(hostname)" && progname="$(basename "$0")" && printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && echo "$dt [$HOST_NAME] [$progname] Start calculating LOC."
  mkdir -p "$JUST_HOME"/output/cloc && mkdir -p "$JUST_HOME"/src/ && echo "    [01/02] Created work folders."
  if [ -d "$JUST_HOME/src/" ] && [ "$(ls -A "$JUST_HOME/src/")" ]; then
    echo "## Lines of Code (LOC) in 'src/' folder:" > "$JUST_HOME"/output/cloc/"$dt"_cloc.txt
    echo ""  >> "$JUST_HOME"/output/cloc/"$dt"_cloc.txt
    cloc "$JUST_HOME"/src/ --timeout 120 --ignored="$JUST_HOME"/output/cloc/"$dt"_cloc_ignored.txt  >> "$JUST_HOME"/output/cloc/"$dt"_cloc.txt
    echo "    [02/02] Calculated LOC."
  else
    echo "  !!! The source code directory is empty. Please unpack the sources with 'just unpack'."
  fi
  printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && echo "$dt [$HOST_NAME] [$progname] End run."
# creates summary CVS reports from all SARIF files present in '/output/sarif' using Microsoft sarif-tools
csv:
  #!/usr/bin/env bash
  set -euo pipefail
  JUST_HOME="$PWD" && \
    HOST_NAME="$(hostname)" && \
    progname="$(basename "$0")" && \
    printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && \
    echo "$dt [$HOST_NAME] [$progname] Start run Microsoft sarif-tools to generate a CSV file from most recent SARIF output."
  mkdir -p "$JUST_HOME"/output/{csv,sarif} && \
    mkdir -p "$JUST_HOME"/logs/sarif-tools/ && \
    mkdir -p "$JUST_HOME"/tmp/ && \
    echo "    [01/06] Created work folders."
  if [ -d "$JUST_HOME/output/sarif/" ] && [ "$(ls -A "$JUST_HOME/output/sarif/")" ]; then
    TEMP_DIR="$(mktemp -q -d "$JUST_HOME"/tmp/csv.XXX)" && echo "    [02/06] Created temporary output folder."
    TEMP_FOLDER="${TEMP_DIR##*/}"
    # sarif tools does not like sarif reports with zero issues, move those reports to /output/sarif/no_results
    for file in "$JUST_HOME"/output/sarif/*.sarif; do
      if [[ -f "$file" ]]; then
        SARIF_RESULTS=0 && SARIF_RESULTS=$(jq -c '.runs[].results | length' "$file" )
        if [ -z "${SARIF_RESULTS:-}" ]; then
          SARIF_RESULTS="0"
        fi
        if [[ "$SARIF_RESULTS" == "0" ]]; then
          mkdir -p "$JUST_HOME/output/sarif/no_results"
          mv "$file" "$JUST_HOME/output/sarif/no_results/"
          file=$(basename "$file")
          echo "       !!! Moved $file (zero issues in sarif report or format error)'."
        fi
      fi
    done
    echo "    [03/07] Moved sarif files with zero results to /output/sarif/no_results."
    sarif csv --autotrim "$JUST_HOME"/output/sarif/*.sarif --output="$TEMP_DIR" &>>"$JUST_HOME"/logs/sarif-tools/"$dt"_sarif-tools_csv.log && \
      echo "    [04/07] Ran sarif-tools over '/output/sarif'."
    cp -r "$TEMP_DIR" "$JUST_HOME"/output/csv/ && echo "    [05/07] Copied output to '/output/csv' folder."
    if cd "$JUST_HOME"/output/csv/; then
      mv -T "$TEMP_FOLDER" "$dt" && echo "    [06/07] Renamed output folder to current (at start) date-time."
    fi
    rm -rf "$TEMP_DIR" 1> /dev/null 2>&1 || true && echo "    [07/07] Removed temporary folder."
  else
    echo "  !!! The SARIF folder '/output/sarif' is empty. Please run some scans first."
  fi
  printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && echo "$dt [$HOST_NAME] [$progname] End run."
# performs SCA with OWASP depscan over sources in '/src'
_depscan:
  #!/usr/bin/env bash
  set -euo pipefail
  JUST_HOME="$PWD" && HOST_NAME="$(hostname)" && progname="$(basename "$0")" && printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && echo "$dt [$HOST_NAME] [$progname] Start OWASP depscan (Warning: can take a long time)."
  mkdir -p "$JUST_HOME"/output/depscan/ && mkdir -p "$JUST_HOME"/tmp/ && mkdir -p "$JUST_HOME"/data/depscan/vdb_home && echo "    [01/07] Created work folders."
  if [ -d "$JUST_HOME/src/" ] && [ "$(ls -A "$JUST_HOME/src/")" ]; then
    TEMP_DIR="$(mktemp -q -d "$JUST_HOME"/tmp/depscan.XXX)"
    TEMP_FOLDER="${TEMP_DIR##*/}"
    cd "$TEMP_DIR" # whatever reports folder defined, depscan put bom.json with sources (to verify if same with docker)
    docker run --quiet --rm -e VDB_HOME=/db -v "$JUST_HOME"/src:/app -v "$JUST_HOME"/data/depscan/vdb_home:/db -v "$TEMP_DIR":/reports \
      ghcr.io/owasp-dep-scan/dep-scan \
      depscan --no-banner --src /app --reports-dir /reports --profile appsec --explain && echo "    [02/07] Ran depscan with output in temporary folder."
    cd "$JUST_HOME"
    cp -r "$TEMP_DIR" "$JUST_HOME"/output/depscan/ && echo "    [03/07] Copied output to '/output/depscan' folder."
    if cd "$JUST_HOME"/output/depscan/; then
      mv -T "$TEMP_FOLDER" "$dt" && echo "    [04/07] Renamed output folder to current (at start) date-time."
    fi
    touch "$JUST_HOME"/src/bom.json && mv "$JUST_HOME"/src/bom.json "$JUST_HOME"/output/depscan/"$dt"/ && echo "    [05/07] Moved bom.json to report folder."
    touch "$JUST_HOME"/src/bom.vdr.json && mv "$JUST_HOME"/src/bom.vdr.json "$JUST_HOME"/output/depscan/"$dt"/ && echo "    [06/07] Moved bom.vdr.json to report folder."
    rm -rf "$TEMP_DIR" 1> /dev/null 2>&1 || true && echo "    [07/07] Removed temporary folder."
  else
    echo "  !!! The source code directory '/src' is empty. Please unpack the sources with 'just unpack'."
  fi
  printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && echo "$dt [$HOST_NAME] [$progname] End run."
# installs 'gitleaks' using Homebrew. Needs Internet access.
_gitleaks-brew: _homebrew
  #!/usr/bin/env bash
  set -euo pipefail
  JUST_HOME="$PWD" && HOST_NAME="$(hostname)" && progname="$(basename "$0")" && printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && echo "$dt [$HOST_NAME] [$progname] Check installation of 'gitleaks'."
  if ! [ -d "$JUST_HOME/logs/homebrew/" ] ; then
    mkdir -p "$JUST_HOME"/logs/homebrew
  fi
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
  printf -v safe_dt '%(%Y%m%d_%H%M%S)T' -1
  brew install gitleaks  &> "$JUST_HOME"/logs/homebrew/"$safe_dt"_homebrew_gitleaks_installation.log
  gitleaks_version=$(gitleaks --version)
  printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && echo "$dt [$HOST_NAME] [$progname] Finished setting up 'gitleaks' ($gitleaks_version)."
# detects secrets like passwords, API keys, and tokens in '/src'
gitleaks: _gitleaks-brew
  #!/usr/bin/env bash
  set -euo pipefail
  JUST_HOME="$PWD" && \
    HOST_NAME="$(hostname)" && \
    progname="$(basename "$0")" && \
    printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && \
    printf -v safe_dt '%(%Y%m%d_%H%M%S)T' -1 && \
    echo "$dt [$HOST_NAME] [$progname] Start Gitleaks."
  mkdir -p "$JUST_HOME"/output/gitleaks && \
    mkdir -p "$JUST_HOME"/logs/gitleaks && \
    mkdir -p "$JUST_HOME"/output/sarif/{old,no_results} && \
    mkdir -p "$JUST_HOME"/src && \
    echo "    [01/05] Created work folders."
  if [ -d "$JUST_HOME/src/" ] && [ "$(ls -A "$JUST_HOME/src/")" ]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    echo "    [02/05] Running Gitleaks scan..."
    if gitleaks dir --no-banner --no-color --ignore-gitleaks-allow --exit-code 0 --report-format sarif --report-path "$JUST_HOME"/output/gitleaks/"$safe_dt"_gitleaks.sarif "$JUST_HOME/src/" &>>"$JUST_HOME"/logs/gitleaks/"$safe_dt"_gitleaks.sarif.log; then
      echo "    [03/05] Gitleaks scan completed successfully."
    else
      echo "  !!! WARNING: Gitleaks completed with errors. Check $JUST_HOME/logs/gitleaks/"$safe_dt"_gitleaks.sarif.log"
    fi
    if [ ! -f "$JUST_HOME"/output/gitleaks/"$safe_dt"_gitleaks.sarif ]; then
      echo "  !!! ERROR: Gitleaks did not create SARIF output file."
      printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && echo "$dt [$HOST_NAME] [$progname] End 'gitleaks' run with ERROR - no output."
      exit 1
    fi
    mv --force "$JUST_HOME"/output/sarif/*gitleaks.sarif "$JUST_HOME"/output/sarif/old/ 2>/dev/null || true
    echo "    [04/05] Removed earlier GITLEAKS SARIF output from '/output/sarif' folder."
    cp "$JUST_HOME"/output/gitleaks/"$safe_dt"_gitleaks.sarif "$JUST_HOME"/output/sarif/"$safe_dt"_gitleaks.sarif && \
      echo "    [05/05] Copied SARIF results to '/output/sarif'."
    if ! command -v jq >/dev/null 2>&1; then
      sudo apt install jq
    fi
    GITLEAKS_RESULTS=0
    if [ -f "$JUST_HOME"/output/sarif/"$safe_dt"_gitleaks.sarif ]; then
      GITLEAKS_RESULTS=$(jq -c '.runs[].results | length' "$JUST_HOME"/output/sarif/"$safe_dt"_gitleaks.sarif 2>/dev/null || echo "0")
    fi
  else
    echo "  !!! ERROR: The source code folder '/src' is empty. Please unpack the sources with 'just unpack'."
    printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && echo "$dt [$HOST_NAME] [$progname] End run with ERROR - no source code."
    exit 1
  fi
  printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && echo "$dt [$HOST_NAME] [$progname] End 'gitleaks' run with $GITLEAKS_RESULTS findings."
# installs Homebrew if not already installed.
_homebrew:
  #!/usr/bin/env bash
  set -euo pipefail
  JUST_HOME="$PWD" && HOST_NAME="$(hostname)" && progname="$(basename "$0")" && printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && echo "$dt [$HOST_NAME] [$progname] Check installation of 'Homebrew'."
  source /home/"$USER"/.bashrc
  sudo apt -y update && sudo apt -y install build-essential curl gcc git ruby-full
  if ! command -v brew >/dev/null 2>&1; then
    if ! [ -d "$JUST_HOME/logs/homebrew/" ] ; then
      mkdir -p "$JUST_HOME"/logs/homebrew
    fi
    printf -v safe_dt '%(%Y%m%d_%H%M%S)T' -1
    export NONINTERACTIVE=1 && /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" &> "$JUST_HOME"/logs/homebrew/"$safe_dt"_homebrew_installation.log
    echo >> /home/"$USER"/.bashrc
    echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> /home/"$USER"/.bashrc
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    source /home/"$USER"/.bashrc
    brew analytics off
  fi
  brew_version=$(brew --version)
  printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && echo "$dt [$HOST_NAME] [$progname] Finished setting up 'Homebrew' ($brew_version)."
# checks cloud config (using KICS) over sources in '/src'
kics:
  #!/usr/bin/env bash
  set -euo pipefail
  JUST_HOME="$PWD" && \
    HOST_NAME="$(hostname)" && \
    progname="$(basename "$0")" && \
    printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && \
    printf -v safe_dt '%(%Y%m%d_%H%M%S)T' -1 && \
    echo "$dt [$HOST_NAME] [$progname] Start Checkmarx KICS."
  USER_UID=$(id -u)
  USER_GID=$(id -g)
    mkdir -p "$JUST_HOME"/output/kics && \
    mkdir -p "$JUST_HOME"/logs/kics && \
    mkdir -p "$JUST_HOME"/output/sarif/{old,no_results} && \
    mkdir -p "$JUST_HOME"/src && \
    echo "    [01/04] Created work folders."
  if [ -f "$JUST_HOME/".gitignore ] && [ -w "$JUST_HOME"/.gitignore ]; then
    mv "$JUST_HOME"/.gitignore "$JUST_HOME"/"$dt"_gitignore
  fi
  if [ -d "$JUST_HOME/src/" ] && [ "$(ls -A "$JUST_HOME/src/")" ]; then
    TEMP_DIR="$(mktemp -q -d "$JUST_HOME"/src/kics.XXX)"
    TEMP_FOLDER="${TEMP_DIR##*/}"
    if docker info > /dev/null 2>&1; then
      echo "    [02/07] Running KICS scan..."
      if docker run --rm -t -u "$USER_UID":"$USER_GID" -v "$JUST_HOME/src/":/path docker.io/checkmarx/kics scan -p /path -o "/path/$TEMP_FOLDER" -e "/path/**/test" -e "/path/**/tests" --no-color --silent --report-formats "all" --output-name "kics-result" --exclude-gitignore; then
        echo "    [02/07] KICS scan completed successfully."
      else
        echo "  !!! WARNING: KICS scan completed with errors or findings. Check logs for details."
      fi
      if [ ! -f "$TEMP_DIR"/kics-result.sarif ]; then
        echo "  !!! ERROR: KICS did not create SARIF output file. Check logs at $JUST_HOME/logs/kics/"
        rm -rf "$TEMP_DIR" 2>&1 || true
        if [ -f "$JUST_HOME"/"$dt"_gitignore ] && [ -w "$JUST_HOME"/"$dt"_gitignore ]; then
          mv "$JUST_HOME"/"$dt"_gitignore "$JUST_HOME"/.gitignore
        fi
        printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && echo "$dt [$HOST_NAME] [$progname] End run with ERROR - no output created."
        exit 1
      fi
      cp -r "$TEMP_DIR" "$JUST_HOME"/output/kics/ && echo "    [03/07] Copied output to '/output/kics' folder."
      mv --force "$JUST_HOME"/output/sarif/*kics.sarif "$JUST_HOME"/output/sarif/old/ 2>/dev/null || true
      echo "    [04/07] Removed earlier KICS SARIF output from '/output/sarif' folder."
      cp "$JUST_HOME"/output/kics/"$TEMP_FOLDER"/kics-result.sarif "$JUST_HOME"/output/sarif/"$safe_dt"_kics.sarif && \
        echo "    [05/07] Copied SARIF results to '/output/sarif'."
      if cd "$JUST_HOME"/output/kics/; then
        mv -T "$TEMP_FOLDER" "$safe_dt" && echo "    [06/07] Renamed output folder to current date-time."
      fi
      rm -rf "$TEMP_DIR" 2>&1 || true
      echo "    [07/07] Removed temporary folder."
    else
      echo "  !!! ERROR: KICS uses docker, and it isn't running - please start docker and try again!"
      if [ -f "$JUST_HOME"/"$dt"_gitignore ] && [ -w "$JUST_HOME"/"$dt"_gitignore ]; then
        mv "$JUST_HOME"/"$dt"_gitignore "$JUST_HOME"/.gitignore
      fi
      printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && echo "$dt [$HOST_NAME] [$progname] End run with ERROR - Docker not available."
      exit 1
    fi
  else
    echo "  !!! ERROR: The source code folder '/src' is empty. Please unpack the sources with 'just unpack'."
    if [ -f "$JUST_HOME"/"$dt"_gitignore ] && [ -w "$JUST_HOME"/"$dt"_gitignore ]; then
      mv "$JUST_HOME"/"$dt"_gitignore "$JUST_HOME"/.gitignore
    fi
    printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && echo "$dt [$HOST_NAME] [$progname] End run with ERROR - no source code."
    exit 1
  fi
  KICS_RESULTS=0
  if [ -f "$JUST_HOME"/output/sarif/"$safe_dt"_kics.sarif ]; then
    KICS_RESULTS=$(jq -c '.runs[].results | length' "$JUST_HOME"/output/sarif/"$safe_dt"_kics.sarif 2>/dev/null || echo "0")
  fi
  if [ -f "$JUST_HOME"/"$dt"_gitignore ] && [ -w "$JUST_HOME"/"$dt"_gitignore ]; then
    mv "$JUST_HOME"/"$dt"_gitignore "$JUST_HOME"/.gitignore
  fi
  printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && echo "$dt [$HOST_NAME] [$progname] End run with $KICS_RESULTS findings."
# installs Homebrew if needed (required by OWASP Noir installation). Needs Internet access.
_noir-brew: _homebrew
  #!/usr/bin/env bash
  set -euo pipefail
  JUST_HOME="$PWD" && HOST_NAME="$(hostname)" && progname="$(basename "$0")" && printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && echo "$dt [$HOST_NAME] [$progname] Check installation of 'OWASP Noir'."
  if ! [ -d "$JUST_HOME/logs/homebrew/" ] ; then
    mkdir -p "$JUST_HOME"/logs/homebrew
  fi
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
  if ! command -v brew >/dev/null 2>&1; then
    echo "  !!! Homebrew not installed (will never happen, but I have a cat). Try installing it with 'just _homebrew'."
  else
    printf -v safe_dt '%(%Y%m%d_%H%M%S)T' -1
    brew install noir  &> "$JUST_HOME"/logs/homebrew/"$safe_dt"_homebrew_noir_installation.log
  fi
  noir_version=$(noir --version)
  printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && echo "$dt [$HOST_NAME] [$progname] Finished checking installation of 'OWASP Noir' (Noir $noir_version)."
# runs OWASP Noir to determine Attack Surface (not using AI)
noir: _noir-brew
  #!/usr/bin/env bash
  set -euo pipefail
  JUST_HOME="$PWD" && \
    HOST_NAME="$(hostname)" && \
    progname="$(basename "$0")" && \
    printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && \
    printf -v safe_dt '%(%Y%m%d_%H%M%S)T' -1 && \
    echo "$dt [$HOST_NAME] [$progname] Start run OWASP Noir to identify the attack surface."
  mkdir -p "$JUST_HOME"/output/noir && \
    mkdir -p "$JUST_HOME"/logs/noir && \
    mkdir -p "$JUST_HOME"/output/sarif/{old,no_results} && \
    mkdir -p "$JUST_HOME"/src && \
    echo "    [01/04] Created work folders."
  if [ -d "$JUST_HOME/src/" ] && [ "$(ls -A "$JUST_HOME/src/")" ]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    echo "    [02/04] Running OWASP Noir scan..."
    if noir -b "$JUST_HOME"/src -T --format sarif --no-color -o "$JUST_HOME"/output/noir/"$safe_dt"_noir.sarif 2>&1 | tee "$JUST_HOME"/logs/noir/"$safe_dt"_noir.sarif.log; then
      noir_version=$(noir --version 2>/dev/null || echo "unknown")
      echo "    [02/04] Successfully ran Noir $noir_version and created report in SARIF format."
    else
      echo "  !!! WARNING: Noir completed with errors. Check $JUST_HOME/logs/noir/"$safe_dt"_noir.sarif.log"
    fi
    if [ ! -f "$JUST_HOME"/output/noir/"$safe_dt"_noir.sarif ]; then
      echo "  !!! ERROR: Noir did not create SARIF output file."
      noir_version=$(noir --version 2>/dev/null || echo "unknown")
      printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && echo "$dt [$HOST_NAME] [$progname] End 'OWASP Noir' ($noir_version) run with ERROR - no output."
      exit 1
    fi
    mv --force "$JUST_HOME"/output/sarif/*noir.sarif "$JUST_HOME"/output/sarif/old/ 2>/dev/null || true
    echo "    [03/04] Removed earlier NOIR SARIF output from '/output/sarif' folder."
    cp "$JUST_HOME"/output/noir/"$safe_dt"_noir.sarif "$JUST_HOME"/output/sarif/ && echo "    [04/04] Copied SARIF results to '/output/sarif' folder."
    NOIR_RESULTS=0
    if [ -f "$JUST_HOME"/output/sarif/"$safe_dt"_noir.sarif ]; then
      NOIR_RESULTS=$(jq -c '.runs[].results | length' "$JUST_HOME"/output/sarif/"$safe_dt"_noir.sarif 2>/dev/null || echo "0")
    fi
  else
    echo "  !!! ERROR: The source code folder '/src' is empty. Please unpack the sources first with 'just unpack'."
    noir_version=$(noir --version 2>/dev/null || echo "unknown")
    printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && echo "$dt [$HOST_NAME] [$progname] End run with ERROR - no source code."
    exit 1
  fi
  noir_version=$(noir --version 2>/dev/null || echo "unknown")
  printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && echo "$dt [$HOST_NAME] [$progname] End run 'OWASP Noir' ($noir_version) with $NOIR_RESULTS findings."
# verifies installation of 'Opengrep'
_opengrep-wget:
  #!/usr/bin/env bash
  set -euo pipefail
  JUST_HOME="$PWD" && HOST_NAME="$(hostname)" && progname="$(basename "$0")" && printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && echo "$dt [$HOST_NAME] [$progname] Check installation of 'opengrep'."
  if ! command -v wget >/dev/null 2>&1; then
    sudo apt install wget
  fi
  if ! command -v git >/dev/null 2>&1; then
    sudo apt install git
  fi
  if ! command -v opengrep >/dev/null 2>&1; then
    echo "    [01/02] Installing 'Opengrep'."
    arch=$(uname -m)
    og_version=$(curl -s https://api.github.com/repos/opengrep/opengrep/releases/latest | grep -oP '"tag_name": "\K(.*)(?=")') && \
      if [[ -n "$og_version" && "$arch" == *arm* ]] ; \
       then sudo wget --quiet --output-document /usr/local/bin/opengrep https://github.com/opengrep/opengrep/releases/download/"$og_version"/opengrep_manylinux_aarch64 ; \
       else sudo wget --quiet --output-document /usr/local/bin/opengrep https://github.com/opengrep/opengrep/releases/download/"$og_version"/opengrep_manylinux_x86 ; \
      fi && \
      sudo chmod a+x /usr/local/bin/opengrep || true
  else
    echo "    [01/02] 'Opengrep' is already installed."
  fi
  mkdir -p "$JUST_HOME"/data
  if [[ -d "$JUST_HOME/data/opengrep-rules" ]]; then
    echo "    [02/02] 'opengrep-rules' are already installed."
  else
    echo "    [02/02] Installing 'opengrep-rules'."
    cd "$JUST_HOME"/data
    sudo rm -rf "$JUST_HOME"/data/opengrep-rules || true
    git clone --quiet --depth 1 https://github.com/opengrep/opengrep-rules.git &>/dev/null
    if cd opengrep-rules; then # https://unicolet.blogspot.com/2025/04/opengrep-quickstart.html
      rm -rf .git
      rm -rf .github
      rm -rf .pre-commit-config.yaml
      rm -rf template.yaml
      find . -type f -not -iname "*.yaml" -delete
    fi
  fi
  og_version=$(opengrep --version)
  printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && echo "$dt [$HOST_NAME] [$progname] Finished setting up 'Opengrep' (Opengrep $og_version)."
# runs Opengrep static analysis over sources in '/src'
opengrep: _opengrep-wget
  #!/usr/bin/env bash
  set -euo pipefail
  JUST_HOME="$PWD" && \
    HOST_NAME="$(hostname)" && \
    progname="$(basename "$0")" && \
    printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && \
    printf -v safe_dt '%(%Y%m%d_%H%M%S)T' -1 && \
    echo "$dt [$HOST_NAME] [$progname] Start 'Opengrep' static analysis over sources in /src."
  mkdir -p "$JUST_HOME"/output/{opengrep,sarif} && \
    mkdir -p "$JUST_HOME"/logs/opengrep && \
    mkdir -p "$JUST_HOME"/output/sarif/{old,no_results} && \
    mkdir -p "$JUST_HOME"/src/ && \
    echo "    [01/05] Created work folders."
  if [ -f "$JUST_HOME/".gitignore ] && [ -w "$JUST_HOME"/.gitignore ]; then
    mv "$JUST_HOME"/.gitignore "$JUST_HOME"/"$dt"_gitignore
  fi
  if [ -d "$JUST_HOME/src/" ] && [ "$(ls -A "$JUST_HOME/src/")" ]; then
    echo "    [02/05] Running Opengrep TXT scan (all severities)..."
    if opengrep scan -f "$JUST_HOME"/data/opengrep-rules \
      --exclude-rule="data.opengrep-rules.typescript.react.best-practice.define-styled-components-on-module-level" \
      --exclude-rule="data.opengrep-rules.typescript.react.portability.i18next.jsx-not-internationalized" \
      --dataflow-traces \
      --taint-intrafile \
      --exclude=test \
      --exclude=tests \
      --text \
      --experimental \
      --project-root="$JUST_HOME"/src "$JUST_HOME"/src &>>"$JUST_HOME"/logs/opengrep/"$safe_dt"_opengrep_txt.log > "$JUST_HOME"/output/opengrep/"$safe_dt"_opengrep.txt; then
      echo "    [02/05] Opengrep TXT scan completed successfully."
    else
      echo "  !!! WARNING: Opengrep TXT scan completed with errors. Check $JUST_HOME/logs/opengrep/"$safe_dt"_opengrep_txt.log"
    fi
    echo "    [03/05] Running Opengrep SARIF scan (WARNING/ERROR only)..."
    if opengrep scan -f "$JUST_HOME"/data/opengrep-rules \
      --exclude-rule="data.opengrep-rules.typescript.react.best-practice.define-styled-components-on-module-level" \
      --exclude-rule="data.opengrep-rules.typescript.react.portability.i18next.jsx-not-internationalized" \
      --dataflow-traces \
      --taint-intrafile \
      --severity=WARNING \
      --severity=ERROR \
      --exclude=test \
      --exclude=tests \
      --sarif \
      --experimental \
      --project-root="$JUST_HOME"/src "$JUST_HOME"/src &>>"$JUST_HOME"/logs/opengrep/"$safe_dt"_opengrep_sarif.log > "$JUST_HOME"/output/opengrep/"$safe_dt"_opengrep.sarif; then
      echo "    [03/05] Opengrep SARIF scan completed successfully."
    else
      echo "  !!! WARNING: Opengrep SARIF scan completed with errors. Check $JUST_HOME/logs/opengrep/"$safe_dt"_opengrep_sarif.log"
    fi
    if [ ! -f "$JUST_HOME"/output/opengrep/"$safe_dt"_opengrep.sarif ]; then
      echo "  !!! ERROR: Opengrep did not create SARIF output file."
      if [ -f "$JUST_HOME"/"$dt"_gitignore ] && [ -w "$JUST_HOME"/"$dt"_gitignore ]; then
        mv "$JUST_HOME"/"$dt"_gitignore "$JUST_HOME"/.gitignore
      fi
      og_version=$(opengrep --version 2>/dev/null || echo "unknown")
      printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && echo "$dt [$HOST_NAME] [$progname] End 'Opengrep' ($og_version) run with ERROR - no SARIF output."
      exit 1
    fi
    mv --force "$JUST_HOME"/output/sarif/*opengrep.sarif "$JUST_HOME"/output/sarif/old/ 2>/dev/null || true
    echo "    [04/05] Removed earlier OPENGREP SARIF output from '/output/sarif' folder."
    cp "$JUST_HOME"/output/opengrep/"$safe_dt"_opengrep.sarif "$JUST_HOME"/output/sarif/
    echo "    [05/05] Copied SARIF results to '/output/sarif' folder."
  else
    echo "  !!! ERROR: The source code directory is empty. Please unpack the sources with 'just unpack'."
    if [ -f "$JUST_HOME"/"$dt"_gitignore ] && [ -w "$JUST_HOME"/"$dt"_gitignore ]; then
      mv "$JUST_HOME"/"$dt"_gitignore "$JUST_HOME"/.gitignore
    fi
    printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && echo "$dt [$HOST_NAME] [$progname] End run with ERROR - no source code."
    exit 1
  fi
  if [ -f "$JUST_HOME"/"$dt"_gitignore ] && [ -w "$JUST_HOME"/"$dt"_gitignore ]; then
    mv "$JUST_HOME"/"$dt"_gitignore "$JUST_HOME"/.gitignore
  fi
  OPENGREP_RESULTS=0
  if [ -f "$JUST_HOME"/output/sarif/"$safe_dt"_opengrep.sarif ]; then
    OPENGREP_RESULTS=$(jq -c '.runs[].results | length' "$JUST_HOME"/output/sarif/"$safe_dt"_opengrep.sarif 2>/dev/null || echo "0")
  fi
  og_version=$(opengrep --version 2>/dev/null || echo "unknown")
  printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && echo "$dt [$HOST_NAME] [$progname] End 'Opengrep' ($og_version) run with $OPENGREP_RESULTS findings."
# runs Google OSV scanner for SCA over sources in '/src'
osv-scanner:
  #!/usr/bin/env bash
  set -euo pipefail
  JUST_HOME="$PWD" && HOST_NAME="$(hostname)" && progname="$(basename "$0")" && printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && echo "$dt [$HOST_NAME] [$progname] Start run."
  if [ -d "$JUST_HOME"/src/ ] && [ "$(ls -A "$JUST_HOME"/src/)" ]; then
    if docker info > /dev/null 2>&1; then
      # if .gitignore in top level (e.g. you are a baldwin.sh dev) osv-scanner will find that and use it (and it should not).
      if [ -f "$JUST_HOME/".gitignore ] && [ -w "$JUST_HOME"/.gitignore ]; then
        mv "$JUST_HOME"/.gitignore "$JUST_HOME"/"$dt"_gitignore
      fi
      if ! command -v jq >/dev/null 2>&1; then
        sudo apt install jq
      fi
      mkdir -p "$JUST_HOME"/output/{osv,sarif} && \
        mkdir -p "$JUST_HOME"/logs/osv && \
        mkdir -p "$JUST_HOME"/src/ && \
        echo "    [01/04] Created work folders."
      echo "    [02/04] Running OSV-scanner (Markdown)..."
      if docker run --rm --quiet -v "$JUST_HOME"/src:/src ghcr.io/google/osv-scanner scan --format markdown -r /src src &>>"$JUST_HOME"/logs/osv/"$dt"_osv_markdown.log > "$JUST_HOME"/output/osv/"$dt"_google-osv-scanner.md; then
        echo "    [02/04] OSV-scanner Markdown output completed successfully."
      else
        osv_exit=$?
        if [ $osv_exit -eq 1 ]; then
          echo "    [02/04] OSV-scanner completed - vulnerabilities found (this is normal)."
        else
          echo "  !!! WARNING: OSV-scanner Markdown completed with unexpected exit code $osv_exit. Check $JUST_HOME/logs/osv/"$dt"_osv_markdown.log"
        fi
      fi
      echo "    [03/04] Running OSV-scanner (SARIF)..."
      if docker run --rm --quiet -v "$JUST_HOME"/src:/src ghcr.io/google/osv-scanner scan --format sarif -r /src &>>"$JUST_HOME"/logs/osv/"$dt"_osv_sarif.log > "$JUST_HOME"/output/osv/"$dt"_google-osv-scanner.sarif; then
        echo "    [03/04] OSV-scanner SARIF output completed successfully."
      else
        osv_exit=$?
        if [ $osv_exit -eq 1 ]; then
          echo "    [03/04] OSV-scanner SARIF completed - vulnerabilities found"
        else
          echo "  !!! WARNING: OSV-scanner SARIF completed with unexpected exit code $osv_exit. Check $JUST_HOME/logs/osv/"$dt"_osv_sarif.log"
        fi
      fi
      if [ ! -f "$JUST_HOME"/output/osv/"$dt"_google-osv-scanner.sarif ]; then
        echo "  !!! ERROR: OSV-scanner did not create SARIF output file."
        if [ -f "$JUST_HOME"/"$dt"_gitignore ] && [ -w "$JUST_HOME"/"$dt"_gitignore ]; then
          mv "$JUST_HOME"/"$dt"_gitignore "$JUST_HOME"/.gitignore
        fi
        printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && echo "$dt [$HOST_NAME] [$progname] End 'osv-scanner' run with ERROR - no SARIF output."
        exit 1
      fi
      rm -f "$JUST_HOME"/output/sarif/*google-osv-scanner.sarif 2>/dev/null || true
      cp "$JUST_HOME"/output/osv/"$dt"_google-osv-scanner.sarif "$JUST_HOME"/output/sarif/
      echo "    [04/04] Copied SARIF results to '/output/sarif' folder."
      OSV_RESULTS=0
      if [ -f "$JUST_HOME"/output/sarif/"$dt"_google-osv-scanner.sarif ]; then
        OSV_RESULTS=$(jq -c '.runs[].results | length' "$JUST_HOME"/output/sarif/"$dt"_google-osv-scanner.sarif 2>/dev/null || echo "0")
      fi
    else
      echo "  !!! ERROR: Google OSV uses docker, and it isn't running - please start docker and try again!"
      printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && echo "$dt [$HOST_NAME] [$progname] End run with ERROR - Docker not available."
      exit 1
    fi
  else
    echo "  !!! ERROR: The source code directory is empty. Please unpack the sources with 'just unpack'."
    printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && echo "$dt [$HOST_NAME] [$progname] End run with ERROR - no source code."
    exit 1
  fi
  if [ -f "$JUST_HOME"/"$dt"_gitignore ] && [ -w "$JUST_HOME"/"$dt"_gitignore ]; then
    mv "$JUST_HOME"/"$dt"_gitignore "$JUST_HOME"/.gitignore
  fi
  printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && echo "$dt [$HOST_NAME] [$progname] End 'osv-scanner' run with $OSV_RESULTS findings."
# calculates SHA256 hash of the input source archives
sha256:
  #!/usr/bin/env bash
  set -euo pipefail
  JUST_HOME="$PWD" && HOST_NAME="$(hostname)" && progname="$(basename "$0")" && printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && echo "$dt [$HOST_NAME] [$progname] Start run."
  mkdir -p "$JUST_HOME"/output/sha256 && mkdir -p "$JUST_HOME"/input/  && echo "    [01/04] Created work folders."
  echo "## List of files in 'input' folder:" > "$JUST_HOME"/output/sha256/"$dt"_sha256.txt
  # shellcheck disable=SC2129 # fix later
  echo ""  >> "$JUST_HOME"/output/sha256/"$dt"_sha256.txt
  ls -al "$JUST_HOME"/input/ >> "$PWD"/output/sha256/"$dt"_sha256.txt  && echo "    [02/04] Created list of all files in '/input' folder."
  echo ""  >> "$JUST_HOME"/output/sha256/"$dt"_sha256.txt
  echo "SHA256 checksums of ZIP/7Z archives in '/input' folder:" >> "$JUST_HOME"/output/sha256/"$dt"_sha256.txt
  echo ""  >> "$JUST_HOME"/output/sha256/"$dt"_sha256.txt
  if ls "$JUST_HOME"/input/*.zip 1> /dev/null 2>&1; then
    sha256sum "$JUST_HOME"/input/*.zip >> "$JUST_HOME"/output/sha256/"$dt"_sha256.txt && echo "    [03/04] Created SHA256 checksum of ZIP archives."
  else
    echo "    [03/04] ZIP archives not present in '/input' folder."
  fi
  if ls "$JUST_HOME"/input/*.7z 1> /dev/null 2>&1; then
    sha256sum "$JUST_HOME"/input/*.7z >> "$JUST_HOME"/output/sha256/"$dt"_sha256.txt && echo "    [04/04] Created SHA256 checksum of 7Z archives."
  else
    echo "    [04/04] 7Z archives not present in '/input' folder."
  fi
  printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && echo "$dt [$HOST_NAME] [$progname] End run."
# find vulnerabilities using AI with STRIX in sources in '/src'
strix:
  #!/usr/bin/env bash
  set -euo pipefail
  JUST_HOME="$PWD" && \
    HOST_NAME="$(hostname)" && \
    progname="$(basename "$0")" && \
    printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && echo "$dt [$HOST_NAME] [$progname] Start STRIX."
  mkdir -p "$JUST_HOME"/output/strix && \
    mkdir -p "$JUST_HOME"/src/ && \
    echo "    [01/02] Created work folders."
  if [ -d "$JUST_HOME/src/" ] && [ "$(ls -A "$JUST_HOME/src/")" ]; then
    if docker info > /dev/null 2>&1; then
      cd "$JUST_HOME"/output/strix
      echo "    [02/02] Running STRIX AI-powered vulnerability detection..."
      if strix --target "$JUST_HOME"/src --instruction "Always perform static analysis first."; then
        echo "    [02/02] STRIX completed successfully."
      else
        echo "  !!! WARNING: STRIX completed with errors or found vulnerabilities."
      fi
    else
      echo "  !!! ERROR: STRIX uses docker, and it isn't running - please start docker and try again!"
      cd "$JUST_HOME"
      printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && echo "$dt [$HOST_NAME] [$progname] End run with ERROR - Docker not available."
      exit 1
    fi
  else
    echo "  !!! ERROR: The source code folder '/src' is empty. Please unpack the sources with 'just unpack'."
    printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && echo "$dt [$HOST_NAME] [$progname] End run with ERROR - no source code."
    exit 1
  fi
  cd "$JUST_HOME"
  printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && echo "$dt [$HOST_NAME] [$progname] End run."
# unpacks source archive(s) into '/src'
unpack:
  #!/usr/bin/env bash
  set -euo pipefail
  JUST_HOME="$PWD" && \
    HOST_NAME="$(hostname)" && \
    progname="$(basename "$0")" && \
    printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && \
    echo "$dt [$HOST_NAME] [$progname] Start unpacking source archives."
  # TODO it might just be possible that you received multiple different zip formats. Will unpack fine, but counter actions wrong.
  # TODO better would be to unpack each archive in a subfolder of 'src', maybe subfolder = archive file name
  # TODO check if archives not password protected / are not corrupted
  echo "    [01/03] Creating work folders..."
  mkdir -p "$JUST_HOME"/{src,input} && \
    mkdir -p "$JUST_HOME"/output/unpack 
  echo "    [02/03] Searching for sourcode archives in /input..."
  found=false
  for file in "$JUST_HOME"/input/*.{zip,7z,tar.bz}; do
    if [ -e "$file" ]; then
       found=true
       break
    fi
  done
  if "$found"; then
    if ls "$JUST_HOME"/input/*.zip 1> /dev/null 2>&1; then
      unzip -qq -o "$JUST_HOME"/input/*.zip -d "$JUST_HOME"/src/
      echo "    [03/03] Unzipped ZIP archives to '/src' folder."
    fi
    if ls "$JUST_HOME"/input/*.7z 1> /dev/null 2>&1; then
      7z x "$JUST_HOME"/input/*.7z -o"$JUST_HOME"/src/
      echo "    [03/03] Unzipped 7Z archives to '/src' folder."
    fi
    if ls "$JUST_HOME"/input/*.tar.bz2 1> /dev/null 2>&1; then
      tar -xjf "$JUST_HOME"/input/*.tar.bz2 -C "$JUST_HOME"/src/
      echo "    [03/03] Unzipped TAR.BZ2 archives to '/src' folder."
    fi
    printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && tree -d -L 4 "$JUST_HOME"/src > "$JUST_HOME"/output/unpack/"$dt"_unpack_tree.txt
  else
    echo "      ❌ No Source code archives (ZIP, 7Z or TAR.BZ2) found in '/input' folder."
  fi
  printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && \
    echo "$dt [$HOST_NAME] [$progname] Finished unpacking archives."
# creates '/bin/baldwin.sh' from the current "justfile" (currently Ubuntu only). Warning: overwrites existing!
baldwin:
  #!/usr/bin/env bash
  set -euo pipefail
  JUST_HOME="$PWD" && \
    HOST_NAME="$(hostname)" && \
    progname="$(basename "$0")" && \
    printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && \
    echo "$dt [$HOST_NAME] [$progname] Start run."
  mkdir -p "$JUST_HOME/bin" && \
    mkdir -p "$JUST_HOME"/output/baldwin.sh && \
    echo "    [01/05] Created work folders."
  # shellcheck disable=SC1009,SC1073
  cat << 'EOF' > "$JUST_HOME"/bin/baldwin.sh
  #!/usr/bin/env bash

  # ------ Variables ------
  HOST_NAME="$(hostname)"
  readonly HOST_NAME
  progname="$(basename "$0")"
  readonly progname

  # ------ Helper Functions ------

  # displays an error message and exit
  die() {
    echo ""
    echo "$HOST_NAME $progname  Error: $1" >&2
    echo ""
    exit 1
  }

  # usage function
  usage(){
    cat << HEREDOC

    Usage: $progname --output <path>

    mandatory arguments:
      -o, --output <path>     folder to be created, containing the "justfile"

    optional arguments:
      -h, --help              show this help message and exit

  HEREDOC
  }

  # --- Main Script ---

  # ------ Argument Parsing ------

  # bail if no params

  [ $# -eq 0 ] && usage && exit 1

  # use getopt and store the output into $OPTS
  # note the use of -o for the short options, --long for the long name options
  # and a : for any option that takes a parameter

  if ! OPTS=$(getopt --options="o:h" --longoptions="help,output:" --name "$progname" -- "$@"); then
     echo "Error in command line arguments." >&2 ; usage; exit 1 ;
  fi

  eval set -- "$OPTS"
  while true; do
    case "$1" in
      -h | --help ) usage; exit 0 ;;
      -o | --output ) output_folder="$2"; shift 2 ;;
      -- ) shift; break ;;
      * ) break ;;
    esac
  done

  shift "$(( OPTIND - 1 ))"
  if [ -z "$output_folder" ]; then
    die "Missing -o/--output parameter Use --help for usage."
  fi

  if [ -d "$output_folder" ]; then
    die "Output folder already already exists. Please choose another location."
  fi

  mkdir -p "$output_folder"/{backup,bin,data,input,logs,output,src,tmp} &>/dev/null || true

  # check if output_ folder exists and is writeable
  if [ ! -d "$output_folder" ]; then
    die "Source folder '$output_folder' does not exist or is not a directory."
  else
    realpath_folder=$(realpath "$output_folder")
    if [ ! -w "$realpath_folder" ]; then
      die "Output folder '$output_folder' is not writable."
    fi
  fi
  #shellcheck disable=SC1039
  EOF
  echo "cat > \"\$realpath_folder\"/justfile << 'EOF'" >> "$JUST_HOME"/bin/baldwin.sh
  cat < "$JUST_HOME"/justfile >> "$JUST_HOME"/bin/baldwin.sh
  echo "EOF" >> "$JUST_HOME"/bin/baldwin.sh
  echo "    [02/05] Created $JUST_HOME/bin/baldwin.sh."
  chmod +x "$JUST_HOME"/bin/baldwin.sh
  echo "    [03/05] Made $JUST_HOME/bin/baldwin.sh executable."
  rm -r "$JUST_HOME"/output/baldwin.sh
  "$JUST_HOME"/bin/baldwin.sh -o "$JUST_HOME"/output/baldwin.sh
  echo "    [04/05] Created $JUST_HOME/output/baldwin.sh/justfile."
  if cmp -s "$JUST_HOME"/justfile "$JUST_HOME"/output/baldwin.sh/justfile; then
    echo "    [05/05] Compared output of 'baldwin.sh' with the original justfile. No difference (succes!)."
  else
    echo "    [05/05] Compared output of 'baldwin.sh' with the original justfile. Not the same (failure! - this never happens)."
  fi
  printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && echo "$dt [$HOST_NAME] [$progname] End run."
EOF
