#!/usr/bin/env bash
# filepath: /workspaces/moneke/bin/cvss2svg.sh
# converts a CVSS 3.1 vector string into a SVG representation (TODO other versions)
#
# initial version (garbage in, garbage out)

set -euo pipefail

# Check if the vector string is valid (only mandatory values, with exception for 4.0)
# Returns 0 if not a valid CVSS vector string
# Valid versions are 1.0, 2.0, 3.0, 3.1 and 4.0
validate_cvss() {
  local vector="$1"

  if [[ "$vector" =~ ^CVSS:4\.0/AV:[NALP]/AC:[LH]/PR:[NHL]/UI:[NPA]/VC:[NHL]/VI:[NHL]/VA:[NHL]$/SC:[NHL]/SI:[NHL]/SA:[NHL]$ ]]; then
    echo "4.0"
    return
  fi

  if [[ "$vector" =~ ^CVSS:4\.0/AV:[NALP]/AC:[LH]/PR:[NHL]/UI:[NPA]/VC:[NHL]/VI:[NHL]/VA:[NHL]$ ]]; then
    echo "4.0"
    return
  fi

  if [[ "$vector" =~ ^CVSS:3\.1/AV:[NALP]/AC:[LH]/PR:[NHL]/UI:[NR]/S:[UCR]/C:[NHL]/I:[NHL]/A:[NHL]$ ]]; then
    echo "3.1"
    return
  fi

  if [[ "$vector" =~ ^CVSS:3\.0/AV:[NALP]/AC:[LH]/PR:[NHL]/UI:[NR]/S:[UCR]/C:[NHL]/I:[NHL]/A:[NHL]$ ]]; then
    echo "3.0"
    return
  fi

  if [[ "$vector" =~ ^CVSS:2\.0/AV:[NALP]/AC:[LH]/Au:[NLA]/C:[NHL]/I:[NHL]/A:[NHL]$ ]]; then
    echo "2.0"
    return
  fi

  if [[ "$vector" =~ ^CVSS:1\.0/AV:[NALP]/AC:[LH]/Au:[NLA]/C:[NHL]/I:[NHL]/A:[NHL]$ ]]; then
    echo "1.0"
    return
  fi

  echo "0"
}

# Parse CVSS 3.1 vector string and calculate score
parse_cvss_3_1() {
  local vector="$1"

  # Initialize metrics with default values (th lowest possible)
  local AV="N" AC="L" PR="N" UI="N" S="U" C="N" I="N" A="N"

  # Parse the vector string
  IFS='/' read -ra metrics <<< "${vector#CVSS:3.1/}"
  for metric in "${metrics[@]}"; do
    key="${metric%%:*}"
    value="${metric#*:}"
    case "$key" in
      (AV|AC|PR|UI|S|C|I|A)
        declare "$key=$value"
        ;;
    esac
  done

  # Calculate Impact Sub-Score (ISS)
  # ISS = 1 - [(1 - C) * (1 - I) * (1 - A))]
  local iss=0 c_impact=0 i_impact=0 a_impact=0 av_val=0 ac_val=0 pr_val=0 ui_val=0 exploitability=0 impact=0 impact_exp=0 base_score=0

  # Confidentiality impact
  case "$C" in
    H) c_impact=0.44 ;;
    L) c_impact=0.78 ;;
    N) c_impact=1 ;;
    *) c_impact=1 ;;
  esac

  # Integrity impact
  case "$I" in
    H) i_impact=0.44 ;;
    L) i_impact=0.78 ;;
    N) i_impact=1 ;;
    *) i_impact=1 ;;
  esac

  # Convert availability impact
  case "$A" in
    H) a_impact=0.44 ;;
    L) a_impact=0.78 ;;
    N) a_impact=1 ;;
    *) a_impact=1 ;;
  esac

  iss=$(echo "1 - ($c_impact * $i_impact * $a_impact)" | bc -l)

  # Calculate Exploitability
  # Exploitability = 8.22 * AV * AC * PR * UI

  # Attack vector
  case "$AV" in
    N) av_val=0.85 ;;
    A) av_val=0.62 ;;
    L) av_val=0.55 ;;
    P) av_val=0.20 ;;
    *) av_val=0.85 ;;
  esac

  # Attack complexity
  case "$AC" in
    L) ac_val=0.77 ;;
    H) ac_val=0.44 ;;
    *) ac_val=0.77 ;;
  esac

  # Privileges Required
  local pr_val=0
  if [ "$S" = "U" ]; then
    case "$PR" in
      N) pr_val=0.85 ;;
      L) pr_val=0.62 ;;
      H) pr_val=0.27 ;;
      *) pr_val=0.85 ;;
    esac
  else
    case "$PR" in
      N) pr_val=0.85 ;;
      L) pr_val=0.68 ;;
      H) pr_val=0.50 ;;
      *) pr_val=0.85 ;;
    esac
  fi

  # User interaction
  case "$UI" in
    N) ui_val=0.85 ;;
    R) ui_val=0.62 ;;
  esac

  exploitability=$(echo "8.22 * $av_val * $ac_val * $pr_val * $ui_val" | bc -l)

  # Calculate impact

  if [ "$S" = "U" ]; then
    impact=$(echo "6.42 * $iss" | bc -l)
  else
    impact=$(echo "(7.52 * ($iss - 0.029)) - (($iss - 0.02)^15) * 3.25" | bc -l)
  fi

  # Calculate CVSS base score (needs PHD to understand the rounding)

  impact_exp=$(echo "$impact + $exploitability" | bc -l)

  if [ "$(echo "$impact <= 0" | bc -l)" -eq 1 ]; then
    base_score=0
  else
    if [ "$S" = "U" ]; then
      if [ "$(echo "$impact_exp >= 10" | bc -l)" -eq 1 ]; then
        base_score=10
      else
        base_score=$impact_exp
        base_score=$(echo "($base_score+0.05)/1" | bc -l)
      fi
    else
      impact_exp=$(echo "$impact_exp * 1.08" | bc -l)
      if [ "$(echo "$impact_exp >= 10" | bc -l)" -eq 1 ]; then
        base_score=10
      else
        base_score=$impact_exp
        base_score=$(echo "($base_score+0.05)/1" | bc -l)
      fi
    fi
  fi

  # Final rounding round
  base_score=$(printf "%.1f" "$base_score")

  # Severity rating
  local severity
  if (( $(echo "$base_score >= 9.0" | bc -l) )); then
    severity="CRITICAL"
    color="#cc0000"  # Dark red
  elif (( $(echo "$base_score >= 7.0" | bc -l) )); then
    severity="HIGH"
    color="#ff0000"  # Red
  elif (( $(echo "$base_score >= 4.0" | bc -l) )); then
    severity="MEDIUM"
    color="#ff8800"  # Orange
  elif (( $(echo "$base_score > 0.0" | bc -l) )); then
    severity="LOW"
    color="#ffcc00"  # Yellow
  else
    severity="NONE"
    color="#009900"  # Green
  fi

  echo "$base_score|$severity|$color|$vector"
}

# Function to create SVG
create_svg() {
  local result="$1"
  local score="${result%%|*}"
  result="${result#*|}"
  local severity="${result%%|*}"
  result="${result#*|}"
  local color="${result%%|*}"
  local vector="${result#*|}"

  cat << EOF
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<svg width="300" height="150" xmlns="http://www.w3.org/2000/svg">
  <style>
    .title { font: bold 14px Consolas, sans-serif; }
    .score { font: bold 30px Consolas, sans-serif; }
    .severity { font: bold 18px Consolas, sans-serif; }
    .vector { font: bold 10px monospace; }
  </style>

  <!-- Background -->
  <rect x="0" y="0" width="300" height="150" fill="#f0f0f0" rx="10" ry="10" stroke="gray" stroke-width="1"/>

  <!-- Title -->
  <text x="150" y="25" class="title" text-anchor="middle">CVSS 3.1 Base Score</text>

  <!-- Score circle -->
  <circle cx="75" cy="75" r="40" fill="${color}" stroke="black" stroke-width="1" />
  <text x="75" y="85" class="score" text-anchor="middle" fill="white">${score}</text>

  <!-- Severity -->
  <text x="200" y="75" class="severity" text-anchor="middle" fill="${color}">${severity}</text>

  <!-- Vector string -->
  <text x="150" y="135" class="vector" text-anchor="middle">${vector}</text>
</svg>
EOF
}

# Main execution
main() {
  if [ $# -ne 1 ]; then
    echo "Usage: $0 \"CVSS:3.1/AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H\""
    exit 1
  fi

  local vector="$1"

  # Check if bc is available
  if ! command -v bc &> /dev/null; then
    echo "Error: bc is required for calculations but not found."
    echo "Please install it using your package manager (e.g., sudo apt install bc)"
    exit 1
  fi

  local result

  # Validate CVSS vector

  local version
  version=$(validate_cvss "$vector")

  if [ "$version" -eq 0 ]; then
    echo "Invalid CVSS vector string."
    exit 1
  fi

  result=$(parse_cvss_3.1 "$vector")
  create_svg "$result"
}

# Execute the script if not being sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
