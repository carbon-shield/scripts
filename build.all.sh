#!/bin/sh

# Store current working directory
OLDPWD=$(pwd);

# Get directory the script is physically in.
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  TOPBUILDDIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$TOPBUILDDIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
TOPBUILDDIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
export TOPBUILDDIR="$(dirname "${TOPBUILDDIR}")"

sh ./get.repos.sh
sh ./build.cm.sh
sh ./build.twrp.sh
sh ./copy.files.sh

cd ${OLDPWD}

