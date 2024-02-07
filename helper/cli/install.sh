#! /usr/bin/env sh
#
# (c) Veracode, 2022
#
# Install script
#
# This script is to be included in the tarball and invoked directly
# following downloading the tarball.
#

command_exist() {
  type "$@" &> /dev/null
}

test_supported_os() {
  local os_name=$1
  local os_major=$(echo $2 | cut -f 1 -d . )
  local os_minor=$(echo $2 | cut -f 2 -d . )

  if [ -z "${os_major}" ] ; then
    os_major=0
  fi

  if [ -z "${os_minor}" ] ; then
    os_minor=0
  fi

  # Major version must be a number
  if ! (echo "${os_major}" | grep -q '^[0-9][0-9]*$') ; then
    return 1
  fi

  # Minor version of pre-releases may have non-numeric suffix, e.g.,
  # Alpine 3.12_alpha20200122
  os_minor=$(echo "${os_minor}" | grep -o '^[0-9]*')
  if [ -z "${os_minor}" ] ; then
    return 1
  fi

  case "${os_name}" in
    rhel)
      if [ "${os_major}" -ge 7 ] ; then
        return 0
      fi
      ;;
    ubuntu)
      if [ "${os_major}" -gt 18 -o \
           "${os_major}" -eq 18 -a "${os_minor}" -ge 4 ] ; then
        return 0
      fi
      ;;
    debian)
      if [ "${os_major}" -ge 9 ] ; then
        return 0
      fi
      ;;
    centos)
      if [ "${os_major}" -ge 7 ] ; then
        return 0
      fi
      ;;
    fedora)
      if [ "${os_major}" -ge 19 ] ; then
        return 0
      fi
      ;;
    alpine)
      if [ "${os_major}" -gt 3 -o \
           "${os_major}" -eq 3 -a "${os_minor}" -ge 11 ] ; then
        return 0
      fi
      ;;
    esac
    return 1
}

#
# Gather OS information
#
if [ -r /etc/os-release ]; then
  .     /etc/os-release
  if ! test_supported_os "$ID" "$VERSION_ID" ; then
    LINUX_VERSION=${VERSION:-"$VERSION_ID"}
    echo "WARNING: Veracode CLI has not validated support of $ID version $LINUX_VERSION." >&2
  fi
  arch=$(uname -m)
  if [ "$arch" = "x86_64" ]; then
    tgz_suffix=linux_x86
  fi
else
  # test for centos version 6 that does not have /etc/os-release.
  if [ -r /etc/system-release ] ; then
    ID=$(awk '{print $1;}' /etc/system-release | tr [A-Z] [a-z])
    VERSION_ID=$(awk '{print $3;}' /etc/system-release)
    MAJOR_VERSION=$(echo $VERSION_ID | cut -f 1 -d . )
    if [ "$ID" != centos ] || [ "$MAJOR_VERSION" -lt "7" ] ; then
      echo "Veracode CLI has not validated support of $ID version $VERSION_ID."
      exit 1
    fi
    arch=$(uname -m)
    if [ "$arch" = "x86_64" ]; then
      tgz_suffix=linux_x86
    fi
  else
    if command_exist sw_vers; then
      # might be a mac
      ID=$(sw_vers | grep ProductName | awk -F':' '{print tolower($2)}' | tr -d '[:space:]')
      VERSION_ID=$(sw_vers | grep ProductVersion | awk -F':' '{print $2}' | tr -d '[:space:]')
      arch=$(uname -m)
      if [ "$arch" = "arm64" ]; then
        tgz_suffix=macosx_arm64
      elif [ "$arch" = "x86_64" ]; then
        tgz_suffix=macosx_x86
      else 
        echo "Veracode CLI has not validated support of $ID version $VERSION_ID architecture $arch."
      fi
    else
      echo 'WARNING: Veracode CLI has not validated installation on this os distribution.' >&2
    fi
  fi
fi

HOMEBREW=false
if [ "$ID" = macosx ] && [ -x /usr/local/bin/brew ] ; then
  HOMEBREW=true
fi


#
# Installation mode.  The first argument to this script may be "system" or
# "local", in which case we skip the following steps and proceed with the
# script based install.
#
MODE=${1:-'none'}
#if [ $MODE = none ] ; then
  #
  # Test for better install options
  #
#  if [ "$ID" = macosx ] && [ $HOMEBREW = true ] ; then
#    cat << END_BREW_INSTALL
#Found homebrew on your system.  Consider installing using:

#brew tap veracode/veracode-cli
#brew update
#brew install veracode-cli

#END_BREW_INSTALL
#  fi

#  if command_exist apt-get; then
#    cat << END_UBUNTU_INSTALL

# Found apt-get on your system.  In the future, consider installing by retrieving and installing our GPG signing key
#    sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys DF7DD7A50B746DD4
# Adding veracode to your apt repo list and installing
#    sudo add-apt-repository "deb https://tools.veracode.com/veracode-cli/ubuntu stable/"
#    sudo apt-get update
#    sudo apt-get install veracode-cli

#END_UBUNTU_INSTALL
#  fi
#fi

#
# Install system wide configuration
#
BASEDIR="$(dirname "$0")"
VERACODE_CLI_VERSION=$(head -n 1 "${BASEDIR}/VERSION")
TARGET_PREFIX="${TARGET_PREFIX:-"/opt"}"
TARGET_DEST="${TARGET_DEST:-"${TARGET_PREFIX}/veracode/${VERACODE_CLI_VERSION}"}"

# Find an appropriate bin
if [ -d /opt/local/bin ] ; then
  TARGET_BIN_DEFAULT='/opt/local/bin'
elif [ -d /usr/local/bin ] ; then
  TARGET_BIN_DEFAULT='/usr/local/bin'
fi
TARGET_BIN="${TARGET_BIN:-"${TARGET_BIN_DEFAULT}"}"

# Find an appropriate share
if [ -d /opt/local/share ] ; then
  TARGET_SHARE_DEFAULT='/opt/local/share'
elif [ -d /usr/local/share ] ; then
  TARGET_SHARE_DEFAULT='/usr/local/share'
fi
TARGET_SHARE="${TARGET_SHARE:-"${TARGET_SHARE_DEFAULT}"}"

#
# Install locally configuration
#
LOCAL_DEST="$PWD"
LOCAL_BIN="$PWD/bin"
LOCAL_SHARE="$PWD"

if [ "$MODE" = none ] ; then
  cat << END_SCRIPT_INSTALL

Files will be placed in:
$TARGET_DEST
$TARGET_BIN
$TARGET_SHARE
and will require root access to install.

Alternatively, running "install.sh local" will place files in:
$LOCAL_DEST

END_SCRIPT_INSTALL
fi

if [ "$MODE" = local ] ; then
  TARGET_DEST="$LOCAL_DEST"
elif [ "$MODE" != system ] && [ "`id -u`" != 0 ]; then
  exec sudo "$0" "system"
fi

log_me() {
  echo "### $@" >&2
}

if [ ! -e "${TARGET_DEST}" ] || [ "$MODE" = local ] ; then
  echo "==> copying files into \"${TARGET_DEST}\""
  mkdir -p   "$TARGET_DEST"
  chmod 0755 "$TARGET_DEST"
  { cd "${BASEDIR}" ; tar -cf - veracode LICENSE README ;} | tar -xf - -C "$TARGET_DEST"
else
  echo "\"$TARGET_DEST\" exists. aborting" >&2
  exit 1
fi

BIN_PATH=""
if ! [ "$MODE" = local ] ; then
  echo "ln -f -s \"$TARGET_DEST/veracode\" \"$TARGET_BIN/veracode-$VERACODE_CLI_VERSION\""
        ln -f -s  "$TARGET_DEST/veracode"   "$TARGET_BIN/veracode-$VERACODE_CLI_VERSION"
  echo "ln -f -s \"$TARGET_BIN/veracode-$VERACODE_CLI_VERSION\" \"$TARGET_BIN/veracode\""
        ln -f -s  "$TARGET_BIN/veracode-$VERACODE_CLI_VERSION"   "$TARGET_BIN/veracode"
else
  BIN_PATH="$TARGET_DEST/"
fi

cat << WELCOME_MESSAGE

=============================== SUCCESS ========================================

The Veracode CLI is now installed!

If you do not have a Veracode API ID and Secret Key, navigate to 
https://analysiscenter.veracode.com/auth/index.jsp#APICredentialsGenerator
to generate your API credentials and then configure them against the
Veracode CLI using the following command:

${BIN_PATH}veracode configure

WELCOME_MESSAGE
exit 0