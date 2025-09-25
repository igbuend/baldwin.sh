# shellcheck disable=SC1083,SC2148
alias checksum := sha256
alias inspect := appinspector
alias loc := cloc
alias osv := osv-scanner
alias secrets := trufflehog
# read .env file with variables
set dotenv-load := true
# default, just list recipes
default:
  @just --list
# creates a backup of everything in $PWD/backup
backup:
  #!/usr/bin/env bash
  set -euxo pipefail
  JUST_HOME="$PWD" && HOST_NAME="$(hostname)" && progname="$(basename "$0")" && printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && echo "$dt [$HOST_NAME] [$progname] Start run."
  mkdir -p "$JUST_HOME"/{backup,tmp} && tempfolder=$(mktemp -d "$JUST_HOME/tmp/XXXXXX") && echo "    [01/03] Created needed directories."
  tar -jcf "$tempfolder"/"$dt"_backup.tar.bz2 --exclude="$JUST_HOME/backup" --exclude="$tempfolder" "$JUST_HOME"
  cp "$tempfolder"/"$dt"_backup.tar.bz2 "$JUST_HOME"/backup/ && rm "$tempfolder"/"$dt"_backup.tar.bz2
  rm -rf "$tempfolder" || true
  printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && echo "$dt [$HOST_NAME] [$progname] End run."
# Creates "baldwin.sh" from the current "justfile" (currently Ubuntu only). Warning: overwrites existing!
baldwin:
  #!/usr/bin/env bash
  set -euo pipefail
  JUST_HOME="$PWD" && HOST_NAME="$(hostname)" && progname="$(basename "$0")" && printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && echo "$dt [$HOST_NAME] [$progname] Start run."
  mkdir -p "$JUST_HOME/bin" && mkdir -p "$JUST_HOME"/output/baldwin.sh && echo "    [01/05] Created needed directories."
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

  mkdir -p "$output_folder"/input &>/dev/null || true

  # check if output_ folder exists and is writeable
  if [ ! -d "$output_folder" ]; then
    die "Source folder '$output_folder' does not exist or is not a directory."
  else
    realpath_folder=$(realpath "$output_folder")
    if [ ! -w "$realpath_folder" ]; then
      die "Output folder '$output_folder' is not writable."
    fi
  fi

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
    echo "    [05/05] Compared output of 'balwin.sh' with the original justfile. No difference (succes!)."
  else
    echo "    [05/05] Compared output of 'balwin.sh' with the original justfile. Not the same (failure! - this never happens)."
  fi
  printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && echo "$dt [$HOST_NAME] [$progname] End run."
# creates a backup of only the output folder in $PWD/backup
output:
  #!/usr/bin/env bash
  set -euo pipefail
  JUST_HOME="$PWD" && HOST_NAME="$(hostname)" && progname="$(basename "$0")" && printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && echo "$dt [$HOST_NAME] [$progname] Start backing up the 'output' directory."
  mkdir -p "$JUST_HOME"/{tmp,backup,output} && tempfolder=$(mktemp -d "$PWD/tmp/XXXXXX") && echo "    [01/04] Created needed directories."
  cd "$JUST_HOME" && tar -jcf "$tempfolder"/"$dt"_output.tar.bz2 output && echo "    [02/04] Created archive in temporary folder."
  cp "$tempfolder"/"$dt"_output.tar.bz2 "$JUST_HOME"/backup/ && rm "$tempfolder"/"$dt"_output.tar.bz2 && echo "    [03/04] Copied archive to 'backup' folder."
  rm -rf "$tempfolder" &>/dev/null || true && echo "    [04/04] Removed temporary folder."
  confirm="Backup of 'output' directory is "$JUST_HOME"/backup/"$dt"_output.tar.bz2."
  printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && echo "$dt [$HOST_NAME] [$progname] End run. $confirm"
# creates a backup of only the input folder in $PWD/backup
input:
  #!/usr/bin/env bash
  set -euo pipefail
  JUST_HOME="$PWD" && HOST_NAME="$(hostname)" && progname="$(basename "$0")" && printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && echo "$dt [$HOST_NAME] [$progname] Start backing up the 'input' folder."
  mkdir -p "$JUST_HOME"/{backup,input,tmp} && echo "    [01/04] Created needed directories."
  tempfolder=$(mktemp -d "$JUST_HOME/tmp/XXXXXX")
  cd "$JUST_HOME" && tar -jcf "$tempfolder"/"$dt"_input.tar.bz2 input && echo "    [02/04] Created archive in temporary folder."
  cp "$tempfolder"/"$dt"_input.tar.bz2 "$JUST_HOME"/backup/ && rm "$tempfolder"/"$dt"_input.tar.bz2 && echo "    [03/04] Copied archive to 'backup' folder."
  rm -rf "$tempfolder" || true && echo "    [04/04] Removed temporary folder."
  confirm="Backup of 'input' directory is "$JUST_HOME"/backup/"$dt"_input.tar.bz2."
  printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && echo "$dt [$HOST_NAME] [$progname] End run. $confirm"
# Empties all folders except data backup folders
clean:
  #!/usr/bin/env bash
  set -euo pipefail
  JUST_HOME="$PWD" && HOST_NAME="$(hostname)" && progname="$(basename "$0")" && printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && echo "$dt [$HOST_NAME] [$progname] Start emptying all folders (not including 'data' and 'backup')."
  mkdir -p "$JUST_HOME"/{input,logs,notes,output,report,src,tmp} && echo "    [01/08] Created needed directories."
  find "$JUST_HOME"/input -mindepth 1 -delete &>/dev/null && echo "    [02/08] Deleted all files in $JUST_HOME/input/."
  find "$JUST_HOME"/notes -mindepth 1 -delete &>/dev/null && echo "    [03/08] Deleted all files in $JUST_HOME/notes/."
  find "$JUST_HOME"/output -mindepth 1 -delete &>/dev/null && echo "    [04/08] Deleted all files in $JUST_HOME/output/."
  find "$JUST_HOME"/report -mindepth 1 -delete &>/dev/null && echo "    [05/08] Deleted all files in $JUST_HOME/report/."
  find "$JUST_HOME"/src -mindepth 1 -delete &>/dev/null && echo "    [06/08] Deleted all files in $JUST_HOME/src/."
  find "$JUST_HOME"/tmp -mindepth 1 -delete &>/dev/null && echo "    [07/08] Deleted all files in $JUST_HOME/tmp/."
  find "$JUST_HOME"/logs -mindepth 1 -delete &>/dev/null && echo "    [08/08] Deleted all files in $JUST_HOME/logs/."
  printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && echo "$dt [$HOST_NAME] [$progname] End run."
# Empties all folders including data and backup folders
empty:
  #!/usr/bin/env bash
  set -euo pipefail
  JUST_HOME="$PWD" && HOST_NAME="$(hostname)" && progname="$(basename "$0")" && printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && echo "$dt [$HOST_NAME] [$progname] Start emptying all folders (including 'data' and 'backup')."
  mkdir -p "$JUST_HOME"/{backup,data,input,logs,notes,output,report,src,tmp} && echo "    [01/10] Created needed directories."
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
  just sha256
  just unpack
  just cloc
  just appinspector
  just osv-scanner
  just kics
  just trufflehog
  just opengrep
  just depscan
# opens Google gemini-cli
gemini:
  gemini
# upgrades Ubuntu and all seperately installed tools
upgrade:
  #!/usr/bin/env bash
  set -euo pipefail
  JUST_HOME="$PWD" && HOST_NAME="$(hostname)" && progname="$(basename "$0")" && printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && echo "$dt [$HOST_NAME] [$progname] Start update required tools."
  mkdir -p "$JUST_HOME"/logs/dpkg
  if sudo -n true 2>/dev/null; then
    echo "user can run passwordless sudo"
  else
    echo "  !!! user cannot run passwordless sudo"
  fi
  sudo apt update -y && sudo apt upgrade -y
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
  dotnet tool install --global Microsoft.CST.ApplicationInspector.CLI
  pnpm add -g @cyclonedx/cdxgen retire @google/gemini-cli
  printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1
  mkdir -p "$JUST_HOME"/logs/dpkg
  dpkg -l > "$JUST_HOME"/logs/dpkg/"$dt"_dpkg.log
  echo "" >> "$JUST_HOME"/logs/dpkg/"$dt"_dpkg.log
  # shellcheck disable=SC2129 # fix later
  echo "Microsoft Appinspector version: $(appinspector --version)" >> "$JUST_HOME/logs/dpkg/$dt"_dpkg.log
  echo "OWASP depscan version: $(depscan --version)" >> "$JUST_HOME/logs/dpkg/$dt"_dpkg.log
  echo "SARIF tools version: $(sarif --version)" >> "$JUST_HOME/logs/dpkg/$dt"_dpkg.log
  echo "opengrep version: $(opengrep --version)" >> "$JUST_HOME/logs/dpkg/$dt"_dpkg.log
  echo "Google osv-scanner version: $(osv-scanner --version | head -n 1)" >> "$JUST_HOME/logs/dpkg/$dt"_dpkg.log
  if docker info > /dev/null 2>&1; then
    docker pull docker.io/checkmarx/kics:latest
    echo "Checkmarx KICS version: $(docker run docker.io/checkmarx/kics:latest version)" >> "$JUST_HOME/logs/dpkg/$dt"_dpkg.log
    docker pull docker.io/trufflesecurity/trufflehog:latest
    echo "Trufflesecurity truffelhog version: $(docker run docker.io/trufflesecurity/trufflehog:latest --version)" >> "$JUST_HOME/logs/dpkg/$dt"_dpkg.log
  else
    echo "Upgrade uses docker, and it isn't running - please start docker and try again!"
  fi
  printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && echo "$dt [$HOST_NAME] [$progname] End run."
# Analyses technology with AppInspector tool over sources in $PWD/src/
appinspector:
  #!/usr/bin/env bash
  set -euo pipefail
  mkdir -p "$PWD"/output/appinspector
  mkdir -p "$PWD"/logs/appinspector
  mkdir -p "$PWD"/src/
  HOST_NAME="$(hostname)"
  progname="$(basename "$0")"
  printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1
  echo "$dt [$HOST_NAME] [$progname] Start run."
  if [ -d "$PWD/src/" ] && [ "$(ls -A "$PWD/src/")" ]; then
    appinspector analyze --single-threaded --file-timeout 500000 --disable-archive-crawling --log-file-path "$PWD"/logs/appinspector/"$dt"_appinspector_html.log --log-file-level Verbose --output-file-path "$PWD"/output/appinspector/"$dt"_appinspector.html --output-file-format html --no-show-progress -s "$PWD"/src/
    appinspector analyze --file-timeout 500000 --disable-archive-crawling --log-file-path "$PWD"/logs/appinspector/"$dt"_appinspector_json.log --log-file-level Verbose --output-file-path "$PWD"/output/appinspector/"$dt"_appinspector.json --output-file-format json --no-show-progress -s "$PWD"/src/
    appinspector analyze --file-timeout 500000 --disable-archive-crawling --log-file-path "$PWD"/logs/appinspector/"$dt"_appinspector_text.log --log-file-level Verbose --output-file-path "$PWD"/output/appinspector/"$dt"_appinspector.text --output-file-format text --no-show-progress -s "$PWD"/src/
  else
    echo "  !!! The source code directory is empty. Please unpack the sources with 'just unpack'."
  fi
  printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && echo "$dt [$HOST_NAME] [$progname] End run."
# Show Lines of Code (LOC) for sources in src/
cloc:
  #!/usr/bin/env bash
  set -euo pipefail
  HOST_NAME="$(hostname)" && progname="$(basename "$0")"
  printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1
  export dt
  echo "$dt [$HOST_NAME] [$progname] Start run."
  mkdir -p "$PWD"/output/cloc
  mkdir -p "$PWD"/src/
  if [ -d "$PWD/src/" ] && [ "$(ls -A "$PWD/src/")" ]; then
    echo "## Lines of Code (LOC) in 'src/' folder:" > "$PWD"/output/cloc/"$dt"_cloc.txt
    echo ""  >> "$PWD"/output/cloc/"$dt"_cloc.txt
    cloc "$PWD"/src/ --ignored="$PWD"/output/cloc/"$dt"_cloc_ignored.txt  >> "$PWD"/output/cloc/"$dt"_cloc.txt
  else
    echo "  !!! The source code directory is empty. Please unpack the sources with 'just unpack'."
  fi
  printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && echo "$dt [$HOST_NAME] [$progname] End run."
# performs SCA with OWASP depscan over sources in $PWD:/src/
depscan:
  #!/usr/bin/env bash
  set -euo pipefail
  JUST_HOME="$PWD" && HOST_NAME="$(hostname)" && progname="$(basename "$0")" && printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && echo "$dt [$HOST_NAME] [$progname] Start OWASP depscan (Warning: can take a long time)."
  mkdir -p "$JUST_HOME"/output/depscan/ && mkdir -p "$PWD"/tmp/ && echo "    [01/07] Created needed directories."
  if [ -d "$PWD/src/" ] && [ "$(ls -A "$PWD/src/")" ]; then
    TEMP_DIR="$(mktemp -q -d "$JUST_HOME"/tmp/depscan.XXX)"
    TEMP_FOLDER="${TEMP_DIR##*/}"
    cd "$TEMP_DIR" # whatever reports folder defined, depscan put bom.json with sources
    depscan --no-banner --sync --profile research --explain --deep --src "$JUST_HOME"/src/ --reports-dir "$TEMP_DIR" &>/dev/null && echo "    [02/07] Ran depscan with output in temporary folder."
    cd "$JUST_HOME"
    cp -r "$TEMP_DIR" "$JUST_HOME"/output/depscan/ && echo "    [03/07] Copied output to 'output/depscan' folder."
    if cd "$JUST_HOME"/output/depscan/; then
      mv -T $TEMP_FOLDER $dt && echo "    [04/07] Renamed output folder to current (at start) date-time."
    fi
    touch "$JUST_HOME"/src/bom.json && mv "$JUST_HOME"/src/bom.json "$JUST_HOME"/output/depscan/"$dt"/ || true && echo "    [05/07] Moved bom.json to report folder."
    touch "$JUST_HOME"/src/bom.vdr.json && mv "$JUST_HOME"/src/bom.vdr.json "$JUST_HOME"/output/depscan/"$dt"/ || true && echo "    [06/07] Moved bom.vdr.json to report folder."
    rm -rf "$TEMP_DIR" 1> /dev/null 2>&1 || true && echo "    [07/07] Removed temporary folder."
  else
    echo "  !!! The source code directory is empty. Please unpack the sources with 'just unpack'."
  fi
  printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && echo "$dt [$HOST_NAME] [$progname] End run."
# checks cloud config (using KICS) over sources in $PWD:/src/
kics:
  #!/usr/bin/env bash
  set -euo pipefail
  JUST_HOME="$PWD" && HOST_NAME="$(hostname)" && progname="$(basename "$0")" && printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && echo "$dt [$HOST_NAME] [$progname] Start Checkmarx KICS."
  USER_UID=$(id -u)
  USER_GID=$(id -g)
  mkdir -p "$JUST_HOME"/output/{kics,sarif} && mkdir -p "$JUST_HOME"/src/ && echo "    [01/07] Created needed directories."
  if [ -d "$JUST_HOME/src/" ] && [ "$(ls -A "$JUST_HOME/src/")" ]; then
    TEMP_DIR="$(mktemp -q -d "$JUST_HOME"/src/kics.XXX)"
    TEMP_FOLDER="${TEMP_DIR##*/}"
    if docker info > /dev/null 2>&1; then
      docker run -t -u "$USER_UID":"$USER_GID" -v "$PWD"/src/:/path docker.io/checkmarx/kics scan -p /path -o "/path/$TEMP_FOLDER" --no-color --silent --report-formats "all" --output-name "kics-result" --exclude-gitignore || true
      echo "    [02/07] Ran KICS with output in temporary folder."
      cp -r "$TEMP_DIR" "$JUST_HOME"/output/kics/ && echo "    [03/07] Copied output to 'output/kics' folder."
      rm -f "$JUST_HOME"/output/sarif/*kics.sarif || true && echo "    [04/07] Removed earlier KICS SARIF output from 'output/sarif' folder."
      cp "$JUST_HOME"/output/kics/"$TEMP_FOLDER"/kics-result.sarif "$JUST_HOME"/output/sarif/"$dt"_kics.sarif || true && echo "    [05/07] Copied SARIF results to 'output/sarif'."
      if cd "$JUST_HOME"/output/kics/; then
        mv -T $TEMP_FOLDER $dt && echo "    [06/07] Renamed output folder to current (at start) date-time."
      fi
      rm -rf "$TEMP_DIR" 1> /dev/null 2>&1 || true && echo "    [07/07] Removed temporary folder."
    else
      echo "  !!! KICS uses docker, and it isn't running - please start docker and try again!"
    fi
  else
    echo "  !!! The source code directory is empty. Please unpack the sources with 'just unpack'."
  fi
  printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && echo "$dt [$HOST_NAME] [$progname] End run."
# runs Opengrep over sources in "$PWD"/src/
opengrep:
  #!/usr/bin/env bash
  set -euo pipefail
  JUST_HOME="$PWD" && HOST_NAME="$(hostname)" && progname="$(basename "$0")" && printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && echo "$dt [$HOST_NAME] [$progname] Start run."
  mkdir -p "$JUST_HOME"/output/{opengrep,sarif} && mkdir -p "$JUST_HOME"/src/ && echo "    [01/02] Created needed directories."
  if [ -d "$JUST_HOME/src/" ] && [ "$(ls -A "$JUST_HOME/src/")" ]; then
    opengrep scan -f "$JUST_HOME"/data/opengrep-rules --sarif-output="$JUST_HOME"/output/sarif/"$dt"_opengrep.sarif --json-output="$JUST_HOME"/output/opengrep/"$dt"_opengrep.json --text-output="$JUST_HOME"/output/opengrep/"$dt"_opengrep.txt "$JUST_HOME"/src &>/dev/null
    echo "    [02/02] Ran opengrep and created SARIF, JSON and TXT output files."
  else
    echo "  !!! The source code directory is empty. Please unpack the sources with 'just unpack'."
  fi
  printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && echo "$dt [$HOST_NAME] [$progname] End run."
# Runs Google OSV scanner for SCA over sources in "$PWD"/src/
osv-scanner:
  #!/usr/bin/env bash
  set -euo pipefail
  JUST_HOME="$PWD" && HOST_NAME="$(hostname)" && progname="$(basename "$0")" && printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && echo "$dt [$HOST_NAME] [$progname] Start run."
  mkdir -p "$JUST_HOME"/output/{osv,sarif} && mkdir -p "$JUST_HOME"/src/ && echo "    [01/04] Created needed directories."
  if [ -d "$JUST_HOME/src/" ] && [ "$(ls -A "$JUST_HOME/src/")" ]; then
    osv-scanner --call-analysis --no-ignore --format table --recursive "$JUST_HOME"/src/ > ./output/osv/"$dt"_google-osv-scanner.txt || true
    echo "    [02/04] Ran osv-scanner and created TXT results."
    osv-scanner --call-analysis --no-ignore --format sarif --recursive "$JUST_HOME"/src/ > ./output/osv/"$dt"_google-osv-scanner.sarif || true
    echo "    [03/04] Ran osv-scanner and created JSON results."
    rm -f "$JUST_HOME"/output/sarif/*google-osv-scanner.sarif || true
    cp "$JUST_HOME"/output/osv/"$dt"_google-osv-scanner.sarif "$JUST_HOME"/output/sarif/ || true
    echo "    [04/04] Copied SARIF results to ourput/sarif folder."
  else
    echo "  !!! The source code directory is empty. Please unpack the sources with 'just unpack'."
  fi
  printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && echo "$dt [$HOST_NAME] [$progname] End run."
# Calculate SHA256 hash of the input source archives
sha256:
  #!/usr/bin/env bash
  set -euo pipefail
  JUST_HOME="$PWD" && HOST_NAME="$(hostname)" && progname="$(basename "$0")" && printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && echo "$dt [$HOST_NAME] [$progname] Start run."
  mkdir -p "$JUST_HOME"/output/sha256 && mkdir -p "$JUST_HOME"/input/  && echo "    [01/04] Created needed directories."
  echo "## List of files in 'input' folder:" > "$JUST_HOME"/output/sha256/"$dt"_sha256.txt
  # shellcheck disable=SC2129 # fix later
  echo ""  >> "$JUST_HOME"/output/sha256/"$dt"_sha256.txt
  ls -al "$JUST_HOME"/input/ >> "$PWD"/output/sha256/"$dt"_sha256.txt  && echo "    [02/04] Created list of all files in 'input' directory."
  echo ""  >> "$JUST_HOME"/output/sha256/"$dt"_sha256.txt
  echo "SHA256 checksums of ZIP/7Z archives in 'input' folder:" >> "$JUST_HOME"/output/sha256/"$dt"_sha256.txt
  echo ""  >> "$JUST_HOME"/output/sha256/"$dt"_sha256.txt
  if ls "$JUST_HOME"/input/*.zip 1> /dev/null 2>&1; then
    sha256sum "$JUST_HOME"/input/*.zip >> "$JUST_HOME"/output/sha256/"$dt"_sha256.txt && echo "    [03/04] Created SHA256 checksum of ZIP archives."
  else
    echo "    [03/04] ZIP archives not present in 'input' folder."
  fi
  if ls "$JUST_HOME"/input/*.7z 1> /dev/null 2>&1; then
    sha256sum "$JUST_HOME"/input/*.7z >> "$JUST_HOME"/output/sha256/"$dt"_sha256.txt && echo "    [04/04] Created SHA256 checksum of 7Z archives."
  else
    echo "    [04/04] 7Z archives not present in 'input' folder."
  fi
  printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && echo "$dt [$HOST_NAME] [$progname] End run."
# search for secrets with TruffleHog
trufflehog:
  #!/usr/bin/env bash
  set -euo pipefail
  JUST_HOME="$PWD" && HOST_NAME="$(hostname)" && progname="$(basename "$0")" && printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && echo "$dt [$HOST_NAME] [$progname] Start run."
  USER_UID=$(id -u)
  USER_GID=$(id -g)
  mkdir -p "$JUST_HOME"/output/trufflehog && echo "    [01/03] Created needed directories."
  if [ -d "$JUST_HOME/src/" ] && [ "$(ls -A "$JUST_HOME/src/")" ]; then
    if docker info > /dev/null 2>&1; then
      docker run --rm -it -v "$JUST_HOME/src:/pwd" docker.io/trufflesecurity/trufflehog:latest filesystem /pwd > "$JUST_HOME"/output/trufflehog/"$dt"_trufflehog-secrets.txt
  #   docker run --rm -it -u "$USER_UID":"$USER_GID" -v "$JUST_HOME/src:/pwd" docker.io/trufflesecurity/trufflehog:latest filesystem /pwd > "$JUST_HOME"/output/trufflehog/"$dt"_trufflehog-secrets.txt
      echo "    [02/03] Succesfully ran TruffleHog and created report in TXT format"
      docker run --rm -it -v "$JUST_HOME/src:/pwd" docker.io/trufflesecurity/trufflehog:latest --json filesystem /pwd > "$JUST_HOME"/output/trufflehog/"$dt"_trufflehog-secrets.json
  #   docker run --rm -it -u "$USER_UID":"$USER_GID" -v "$JUST_HOME/src:/pwd" docker.io/trufflesecurity/trufflehog:latest --json filesystem /pwd > "$JUST_HOME"/output/trufflehog/"$dt"_trufflehog-secrets.json
      echo "    [03/03] Succesfully ran TruffleHog and created report in JSON format"
    else
      echo "  !!! TruffleHog uses docker, and it isn't running - please start docker and try again!"
    fi
  else
    echo "  !!! The source code directory is empty. Please unpack the sources with 'just unpack'."
  fi
  printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && echo "$dt [$HOST_NAME] [$progname] End run."
# Unzips source archive(s) into $PWD/src/
unpack:
  #!/usr/bin/env bash
  set -euo pipefail
  JUST_HOME="$PWD" && HOST_NAME="$(hostname)" && progname="$(basename "$0")" && printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && echo "$dt [$HOST_NAME] [$progname] Start run."
  # TODO it might just be possible that you received multiple different zip formats. Will unpack fine, but counter actions wrong.
  # TODO better would be to unpack each archive in a subfolder of 'src', maybe subfolder = archive file name
  # TODO check if archives not password protected / are not corrupted
  found=false
  for file in "$JUST_HOME"/input/*.{zip,7z,tar.bz}; do
    if [ -e "$file" ]; then
       found=true
       break
    fi
  done
  if "$found"; then
    echo "    [01/03] Found source code archives in 'input' folder."
    mkdir -p "$JUST_HOME/src" && echo "    [02/03] Created needed directories."
    if ls "$JUST_HOME"/input/*.zip 1> /dev/null 2>&1; then
      unzip "$JUST_HOME"/input/*.zip -d "$JUST_HOME"/src/ &>/dev/null
      echo "    [03/03] Unzipped ZIP archives to 'src' folder ."
    fi
    if ls "$PWD"/input/*.7z 1> /dev/null 2>&1; then
      7z e "$PWD"/input/*.7z -o"$PWD"/src/
      echo "    [03/03] Unzipped 7Z archives to 'src' folder ."
    fi
    if ls "$PWD"/input/*.tar.bz2 1> /dev/null 2>&1; then
      tar -xjf "$PWD"/input/*.tar.bz2 -C "$PWD"/src/
      echo "    [03/03] Unzipped TAR.BZ2 archives to 'src' folder ."
    fi
  else
    echo "  !!! No Source code archives (ZIP, 7Z or TAR.BZ2) found in 'input' folder."
  fi
  printf -v dt '%(%Y-%m-%d_%H:%M:%S)T' -1 && echo "$dt [$HOST_NAME] [$progname] End run."
