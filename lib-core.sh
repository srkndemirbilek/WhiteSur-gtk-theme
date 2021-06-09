# WARNING: Please make this shell not working-directory dependant, for example
# instead of using 'ls blabla', use 'ls "${REPO_DIR}/blabla"'
#
# WARNING: Don't use "cd" in this shell, use it in a subshell instead,
# for example ( cd blabla && do_blabla ) or $( cd .. && do_blabla )
#
# WARNING: Please don't use sudo directly here since it steals our EXIT trap

set -Eeo pipefail

if [[ ! "${REPO_DIR}" ]]; then
  echo "Please define 'REPODIR' variable"; exit 1
elif [[ "${WHITESUR_SOURCE[@]}" =~ "lib-core.sh" ]]; then
  echo "'lib-core.sh' is already imported"; exit 1
fi

WHITESUR_SOURCE=("lib-core.sh")

###############################################################################
#                                VARIABLES                                    #
###############################################################################

export WHITESUR_PID=$$
MY_USERNAME="$(logname 2> /dev/null || echo ${SUDO_USER:-${USER}})"

if command -v gnome-shell &> /dev/null; then
  if (( $(gnome-shell --version | cut -d ' ' -f 3 | cut -d . -f 1) >= 4 )); then
    GNOME_VERSION="new"
  else
    GNOME_VERSION="old"
  fi
else
  GNOME_VERSION="none"
fi

# Program options
SASSC_OPT="-M -t expanded"

if [[ "$(uname -s)" =~ "BSD" || "$(uname -s)" == "Darwin" ]]; then
  SED_OPT="-i """
else
  SED_OPT="-i"
fi

# Directories
THEME_SRC_DIR="${REPO_DIR}/src"
DASH_TO_DOCK_SRC_DIR="${REPO_DIR}/src/other/dash-to-dock"
DASH_TO_DOCK_DIR_ROOT="/usr/share/gnome-shell/extensions/dash-to-dock@micxgx.gmail.com"
DASH_TO_DOCK_DIR_HOME="/home/${MY_USERNAME}/.local/share/gnome-shell/extensions/dash-to-dock@micxgx.gmail.com"
FIREFOX_SRC_DIR="${REPO_DIR}/src/other/firefox"
FIREFOX_DIR_HOME="/home/${MY_USERNAME}/.mozilla/firefox"
FIREFOX_THEME_DIR="/home/${MY_USERNAME}/.mozilla/firefox/firefox-themes"
FIREFOX_FLATPAK_DIR_HOME="/home/${MY_USERNAME}/.var/app/org.mozilla.firefox/.mozilla/firefox"
FIREFOX_FLATPAK_THEME_DIR="/home/${MY_USERNAME}/.var/app/org.mozilla.firefox/.mozilla/firefox/firefox-themes"
FIREFOX_SNAP_DIR_HOME="/home/${MY_USERNAME}/snap/firefox/common/.mozilla/firefox"
FIREFOX_SNAP_THEME_DIR="/home/${MY_USERNAME}/snap/firefox/common/.mozilla/firefox/firefox-themes"
export WHITESUR_TMP_DIR="/tmp/WhiteSur.lock"

if [[ -w "/root" ]]; then
  THEME_DIR="/usr/share/themes"
else
  THEME_DIR="$HOME/.themes"
fi

# GDM
WHITESUR_GS_DIR="/usr/share/gnome-shell/theme/WhiteSur"
COMMON_CSS_FILE="/usr/share/gnome-shell/theme/gnome-shell.css"
UBUNTU_CSS_FILE="/usr/share/gnome-shell/theme/ubuntu.css"
ZORIN_CSS_FILE="/usr/share/gnome-shell/theme/zorin.css"
ETC_CSS_FILE="/etc/alternatives/gdm3.css"
ETC_GR_FILE="/etc/alternatives/gdm3-theme.gresource"
YARU_GR_FILE="/usr/share/gnome-shell/theme/Yaru/gnome-shell-theme.gresource"
POP_OS_GR_FILE="/usr/share/gnome-shell/theme/Pop/gnome-shell-theme.gresource"
MISC_GR_FILE="/usr/share/gnome-shell/gnome-shell-theme.gresource"
GS_GR_XML_FILE="${THEME_SRC_DIR}/main/gnome-shell/gnome-shell-theme.gresource.xml"

# Theme
THEME_NAME="WhiteSur"
COLOR_VARIANTS=('light' 'dark')
OPACITY_VARIANTS=('normal' 'solid')
ALT_VARIANTS=('normal' 'alt')
THEME_VARIANTS=('default' 'blue' 'purple' 'pink' 'red' 'orange' 'yellow' 'green' 'grey')
ICON_VARIANTS=('standard' 'simple' 'gnome' 'ubuntu' 'arch' 'manjaro' 'fedora' 'debian' 'void')
SIDEBAR_SIZE_VARIANTS=('default' '220' '240' '260' '280')
PANEL_OPACITY_VARIANTS=('default' '30' '45' '60' '75')
NAUTILUS_STYLE_VARIANTS=('default' 'stable' 'mojave' 'glassy')

# Customization, default values
dest="${THEME_DIR}"
name="${THEME_NAME}"
colors=("${COLOR_VARIANTS}")
opacities=("${OPACITY_VARIANTS}")
alts=("${ALT_VARIANTS[0]}")
themes=("${THEME_VARIANTS[0]}")
icon="${ICON_VARIANTS[0]}"
sidebar_size="${SIDEBAR_SIZE_VARIANTS[0]}"
panel_opacity="${PANEL_OPACITY_VARIANTS[0]}"
nautilus_style="${NAUTILUS_STYLE_VARIANTS[1]}"
background="default"
compact="true"

# Ambigous arguments checking and overriding default values
declare -A has_set=([-b]="false" [-s]="false" [-p]="false" [-d]="false" [-n]="false" [-a]="false" [-o]="false" [-c]="false" [-i]="false" [-t]="false" [-N]="false")
declare -A need_dialog=([-b]="false" [-s]="false" [-p]="false" [-d]="false" [-n]="false" [-a]="false" [-o]="false" [-c]="false" [-i]="false" [-t]="false" [-N]="false")

# Tweaks
need_help="false"
uninstall="false"
interactive="false"

no_darken="false"
no_blur="false"

firefox="false"
edit_firefox="false"
flatpak="false"
snap="false"
gdm="false"
dash_to_dock="false"
max_round="false"
showapps_normal="false"

# Misc
msg=""
final_msg="Run '${0} --help' to explore more customization features!"
notif_msg=""
process_ids=()
error_snippet=""
export ANIM_PID="0"
has_any_error="false"
swupd_packages=""
swupd_url="https://cdn.download.clearlinux.org/current/x86_64/os/Packages"

# Colors and animation
c_default="\033[0m"
c_blue="\033[1;34m"
c_magenta="\033[1;35m"
c_cyan="\033[1;36m"
c_green="\033[1;32m"
c_red="\033[1;31m"
c_yellow="\033[1;33m"

anim=(
  "${c_blue}•${c_green}•${c_red}•${c_magenta}•         "
  " ${c_green}•${c_red}•${c_magenta}•${c_blue}•        "
  "  ${c_red}•${c_magenta}•${c_blue}•${c_green}•       "
  "   ${c_magenta}•${c_blue}•${c_green}•${c_red}•      "
  "    ${c_blue}•${c_green}•${c_red}•${c_magenta}•     "
)

###############################################################################
#                              CORE UTILITIES                                 #
###############################################################################

start_animation() {
  setterm -cursor off

  (
    while true; do
      for i in {0..4}; do
        echo -ne "\r\033[2K                         ${anim[i]}"
        sleep 0.1
      done

      for i in {4..0}; do
        echo -ne "\r\033[2K                         ${anim[i]}"
        sleep 0.1
      done
    done
  ) &

  export ANIM_PID="${!}"
}

stop_animation() {
  [[ -e "/proc/${ANIM_PID}" ]] && kill -13 "${ANIM_PID}"
  setterm -cursor on
}

# Echo like ... with flag type and display message colors
prompt() {
  case "${1}" in
    "-s")
      echo -e "  ${c_green}${2}${c_default}" ;;    # print success message
    "-e")
      echo -e "  ${c_red}${2}${c_default}" ;;      # print error message
    "-w")
      echo -e "  ${c_yellow}${2}${c_default}" ;;   # print warning message
    "-i")
      echo -e "  ${c_cyan}${2}${c_default}" ;;     # print info message
  esac
}

###############################################################################
#                               SELF SAFETY                                   #
###############################################################################
##### This is the core of error handling, make sure there's no error here #####

### TODO: return "lockWhiteSur()" back for non functional syntax error handling
###       and lock dir removal after immediate terminal window closing

if [[ -d "${WHITESUR_TMP_DIR}" ]]; then
  start_animation; sleep 2; stop_animation; echo

  if [[ -d "${WHITESUR_TMP_DIR}" ]]; then
    prompt -e "ERROR: Whitesur installer or tweaks is already running. Probably it's run by '$(ls -ld "${WHITESUR_TMP_DIR}" | awk '{print $3}')'"
    exit 1
  fi
fi

rm -rf "${WHITESUR_TMP_DIR}"
mkdir -p "${WHITESUR_TMP_DIR}"; exec 2> "${WHITESUR_TMP_DIR}/error_log.txt"

signal_exit() {
  rm -rf "${WHITESUR_TMP_DIR}"
  stop_animation
}

operation_aborted() {
  IFS=$'\n'
  local sources=($(basename -a "${WHITESUR_SOURCE[@]}" "${BASH_SOURCE[@]}" | sort -u))
  local dist_ids=($(awk -F '=' '/ID/{print $2}' "/etc/os-release" | sort -Vru))
  local repo_ver=""
  local lines=()

  if ! repo_ver="$(cd "${REPO_DIR}"; git log -1 --date=format-local:"%FT%T%z" --format="%ad" 2> /dev/null)"; then
    if ! repo_ver="$(date -r "${REPO_DIR}" +"%FT%T%z")"; then
      repo_ver="unknown"
    fi
  fi

  # Some computer may have a bad performance. We need to avoid the error log
  # to be cut. Sleeping for awhile may help
  sleep 0.75; clear

  prompt -e "\n\n  Oops! Operation has been aborted or failed...\n"
  prompt -e "=========== ERROR LOG ==========="

  if ! awk '{printf "\033[1;31m  >>> %s\n", $0}' "${WHITESUR_TMP_DIR}/error_log.txt"; then
    prompt -e ">>>>>>> No error log found <<<<<<"
  fi

  prompt -e "\n  =========== ERROR INFO =========="
  prompt -e "FOUND  :"

  for i in "${sources[@]}"; do
    lines=($(grep -Fn "${error_snippet:-${BASH_COMMAND}}" "${REPO_DIR}/${i}" | cut -d : -f 1 || echo ""))
    prompt -e "  >>> ${i}$(IFS=';'; [[ "${lines[*]}" ]] && echo " at ${lines[*]}")"
  done

  prompt -e "SNIPPET:\n    >>> ${error_snippet:-${BASH_COMMAND}}"
  prompt -e "TRACE  :"

  for i in "${FUNCNAME[@]}"; do
    prompt -e "  >>> ${i}"
  done

  prompt -e "\n  =========== SYSTEM INFO ========="
  prompt -e "DISTRO : $(IFS=';'; echo "${dist_ids[*]}")"
  prompt -e "SUDO   : $([[ -w "/root" ]] && echo "yes" || echo "no")"
  prompt -e "GNOME  : ${GNOME_VERSION}"
  prompt -e "REPO   : ${repo_ver}\n"

  prompt -i "HINT: You can google or report to us the info above\n"
  prompt -i "https://github.com/vinceliuice/WhiteSur-gtk-theme/issues\n\n"

  rm -rf "${WHITESUR_TMP_DIR}"; exit 1
}

rootify() {
  local result=0

  trap true SIGINT
  prompt -w "Executing '$(echo "${@}" | cut -c -35 )...' as root"

  if [[ -p /dev/stdin ]] && ! sudo "${@}" < /dev/stdin || ! sudo "${@}"; then
    error_snippet="${*}"
    result=1
  fi

  trap signal_exit SIGINT

  return "${result}"
}

userify() {
  local result=0

  trap true SIGINT

  if [[ -p /dev/stdin ]] && ! sudo -u "${MY_USERNAME}" "${@}" < /dev/stdin || ! sudo -u "${MY_USERNAME}" "${@}"; then
    error_snippet="${*}"
    result=1
  fi

  trap signal_exit SIGINT

  return "${result}"
}

trap 'operation_aborted' ERR
trap 'signal_exit' INT EXIT TERM

###############################################################################
#                              USER UTILITIES                                 #
###############################################################################

helpify_title() {
  printf "${c_cyan}%s${c_blue}%s ${c_green}%s\n\n" "Usage: " "$0" "[OPTIONS...]"
  printf "${c_cyan}%s\n" "OPTIONS:"
}

helpify() {
  printf "  ${c_blue}%s ${c_green}%s\n ${c_magenta}%s. ${c_cyan}%s\n\n${c_default}" "${1}" "${2}" "${3}" "${4}"
}

# Check command availability
has_command() {
  command -v "$1" &> /dev/null
}

has_flatpak_app() {
  flatpak list --columns=application 2> /dev/null | grep "${1}" &> /dev/null || return 1
}

has_snap_app() {
  snap list "${1}" &> /dev/null || return 1
}

is_my_distro() {
  [[ "$(cat '/etc/os-release' | awk -F '=' '/ID/{print $2}')" =~ "${1}" ]]
}

###############################################################################
#                                 PARAMETERS                                  #
###############################################################################

destify() {
  case "${1}" in
    normal|default|standard)
      echo "" ;;
    *)
      echo "-${1}" ;;
  esac
}

parsimplify() {
  case "${1}" in
    --size)
      echo "-s" ;;
    --panel)
      echo "-p" ;;
    --name|-n)
      # workaround for echo
      echo "~-n" | cut -c 2- ;;
    --dest)
      echo "-d" ;;
    --alt)
      echo "-a" ;;
    --opacity)
      echo "-o" ;;
    --color)
      echo "-c" ;;
    --icon)
      echo "-i" ;;
    --theme)
      echo "-t" ;;
    --nautilus-style)
      echo "-N" ;;
    --background)
      echo "-b" ;;
    *)
      echo "${1}" ;;
  esac
}

check_param() {
  local global_param="$(parsimplify "${1}")"
  local display_param="${2}" # used for aliases
  local value="${3}"
  local must_not_ambigous="${4}" # options: must, optional, not-at-all
  local must_have_value="${5}"   # options: must, optional, not-at-all
  local value_must_found="${6}"  # options: must, optional, not-at-all
  local allow_all_choice="${7}"  # options: true, false

  local has_any_ambiguity_error="false"
  local variant_found="false"

  if [[ "${has_set["${global_param}"]}" == "true" ]]; then
    need_dialog["${global_param}"]="true"

    case "${must_not_ambigous}" in
      must)
        prompt -e "ERROR: Ambigous '${display_param}' option. Choose one only."; has_any_error="true" ;;
      optional)
        prompt -w "WARNING: Ambigous '${display_param}' option. We'll show a chooser dialog when possible" ;;
    esac
  fi

  if [[ "${value}" == "" || "${value}" == "-"*  ]]; then
    need_dialog["${global_param}"]="true"

    case "${must_have_value}" in
      must)
        prompt -e "ERROR: '${display_param}' can't be empty."; has_any_error="true" ;;
      optional)
        prompt -w "WARNING: '${display_param}' can't be empty. We'll show a chooser dialog when possible" ;;
    esac

    has_set["${global_param}"]="true"; return 1
  else
    if [[ "${has_set["${global_param}"]}" == "false" ]]; then
      case "${global_param}" in
        -a)
          alts=() ;;
        -o)
          opacities=() ;;
        -c)
          colors=() ;;
        -t)
          themes=() ;;
      esac
    fi

    case "${global_param}" in
      -d)
        if [[ "$(readlink -m "${value}")" =~ "${REPO_DIR}" ]]; then
          prompt -e "'${display_param}' ERROR: Can't install in the source directory."
          has_any_error="true"
        elif [[ ! -w "${value}" && ! -w "$(dirname "${value}")" ]]; then
          prompt -e "'${display_param}' ERROR: You have no permission to access that directory."
          has_any_error="true"
        else
          if [[ ! -d "${value}" ]]; then
            prompt -w "Destination directory does not exist. Let's make a new one..."; echo
            mkdir -p "${value}"
          fi

          dest="${value}"
        fi

        remind_relative_path "${display_param}" "${value}"; variant_found="skip" ;;
      -b)
        if [[ "${value}" == "blank" || "${value}" == "default" ]]; then
          background="${value}"
        elif [[ ! -r "${value}" ]]; then
          prompt -e "'${display_param}' ERROR: Image file is not found or unreadable."
          has_any_error="true"
        elif file "${value}" | grep -qE "image|bitmap"; then
          background="${value}"
        else
          prompt -e "'${display_param}' ERROR: Invalid image file."
          has_any_error="true"
        fi

        remind_relative_path "${display_param}" "${value}"; variant_found="skip" ;;
      -n)
        name="${value}"; variant_found="skip" ;;
      -s)
        for i in {0..4}; do
          if [[ "${value}" == "${SIDEBAR_SIZE_VARIANTS[i]}" ]]; then
            sidebar_size="${value}"; variant_found="true"; break
          fi
        done ;;
      -p)
        for i in {0..4}; do
          if [[ "${value}" == "${PANEL_OPACITY_VARIANTS[i]}" ]]; then
            panel_opacity="${value}"; variant_found="true"; break
          fi
        done ;;
      -a)
        [[ "${alts_set}" == "false" ]] && alts=()

        if [[ "${value}" == "all" ]]; then
          for i in {0..2}; do
            alts+=("${ALT_VARIANTS[i]}")
          done

          variant_found="true"
        else
          for i in {0..2}; do
            if [[ "${value}" == "${ALT_VARIANTS[i]}" ]]; then
              alts+=("${ALT_VARIANTS[i]}"); variant_found="true"; break
            fi
          done
        fi ;;
      -o)
        for i in {0..1}; do
          if [[ "${value}" == "${OPACITY_VARIANTS[i]}" ]]; then
            opacities+=("${OPACITY_VARIANTS[i]}"); variant_found="true"; break
          fi
        done ;;
      -c)
        for i in {0..1}; do
          if [[ "${value}" == "${COLOR_VARIANTS[i]}" ]]; then
            colors+=("${COLOR_VARIANTS[i]}"); variant_found="true"; break
          fi
        done ;;
      -i)
        for i in {0..8}; do
          if [[ "${value}" == "${ICON_VARIANTS[i]}" ]]; then
            icon="${ICON_VARIANTS[i]}"; variant_found="true"; break
          fi
        done ;;
      -t)
        if [[ "${value}" == "all" ]]; then
          for i in {0..8}; do
            themes+=("${THEME_VARIANTS[i]}")
          done

          variant_found="true"
        else
          for i in {0..8}; do
            if [[ "${value}" == "${THEME_VARIANTS[i]}" ]]; then
              themes+=("${THEME_VARIANTS[i]}")
              variant_found="true"
              break
            fi
          done
        fi ;;
      -N)
        for i in {0..3}; do
          if [[ "${value}" == "${NAUTILUS_STYLE_VARIANTS[i]}" ]]; then
            nautilus_style="${NAUTILUS_STYLE_VARIANTS[i]}"; variant_found="true"; break
          fi
        done ;;
    esac

    if [[ "${variant_found}" == "false" && "${variant_found}" != "skip" ]]; then
      case "${value_must_found}" in
        must)
          prompt -e "ERROR: Unrecognized '${display_param}' variant: '${value}'."; has_any_error="true" ;;
        optional)
          prompt -w "WARNING: '${display_param}' variant of '${value}' isn't recognized. We'll show a chooser dialog when possible"
          need_dialog["${global_param}"]="true" ;;
      esac
    elif [[ "${allow_all_choice}" == "false" && "${value}" == "all" ]]; then
      prompt -e "ERROR: Can't choose all '${display_param}' variants."; has_any_error="true"
    fi

    has_set["${global_param}"]="true"; return 0
  fi
}

avoid_variant_duplicates() {
  colors=($(printf "%s\n" "${colors[@]}" | sort -u))
  opacities=($(printf "%s\n" "${opacities[@]}" | sort -u))
  alts=($(printf "%s\n" "${alts[@]}" | sort -u))
  themes=($(printf "%s\n" "${themes[@]}" | sort -u))
}

# 'finalize_argument_parsing' is in the 'systems' section

###############################################################################
#                                   FILES                                     #
###############################################################################

restore_file() {
  if [[ -f "${1}.bak" ]]; then
    case "${2}" in
      rootify)
        rootify rm -rf "${1}"; rootify mv "${1}"{".bak",""} ;;
      userify)
        userify rm -rf "${1}"; userify mv "${1}"{".bak",""} ;;
      *)
        rm -rf "${1}"; mv "${1}"{".bak",""} ;;
    esac
  fi
}

backup_file() {
  if [[ -f "${1}" ]]; then
    case "${2}" in
      rootify)
        rootify mv -n "${1}"{"",".bak"} ;;
      userify)
        userify mv -n "${1}"{"",".bak"} ;;
      *)
        mv -n "${1}"{"",".bak"} ;;
    esac
  fi
}

userify_file() {
  if [[ -f "${1}" && "$(ls -ld "${1}" | awk '{print $3}')" != "${MY_USERNAME}" ]]; then
    rootify chown "${MY_USERNAME}:" "${1}"
  fi
}

check_theme_file() {
  [[ -f "${1}" || -f "${1}.bak" ]]
}

remind_relative_path() {
  [[ "${2}" =~ "~" ]] && prompt -w "'${1}' REMEMBER: ~/'path to somewhere' and '~/path to somewhere' are different."
}

###############################################################################
#                                    MISC                                     #
###############################################################################

full_rootify() {
  if [[ ! -w "/root" ]]; then
    prompt -e "ERROR: '${1}' needs a root priviledge. Please run this '${0}' as root"
    has_any_error="true"
  fi
}

usage() {
  prompt -e "Usage function is not implemented"; exit 1
}

finalize_argument_parsing() {
  if [[ "${need_help}" == "true" ]]; then
    echo; usage
    [[ "${has_any_error}" == "true" ]] && exit 1 || exit 0
  elif [[ "${has_any_error}" == "true" ]]; then
    echo; prompt -i "Try '$0 --help' for more information."; exit 1
  elif [[ "${need_dialog[@]}" =~ "true" ]]; then
    echo
  fi
}
