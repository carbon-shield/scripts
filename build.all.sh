#!/bin/bash

# Check parameter validity
if [ ! -z "$1" ] && [ ! "$1" == "cm" ] && [ ! "$1" == "twrp" ]; then
	echo "Usage: $0 [cm OR twrp]";
	exit 1;
fi;

# Default list of devices
declare -a BUILDDEVICES=("roth" "shieldtablet");

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

# Create device list if it doesn't exist.
if [ ! -f $TOPBUILDDIR/scripts/devices.txt ]; then
	for dev in "${BUILDDEVICES[@]}"
	do
		echo ${dev} >> $TOPBUILDDIR/scripts/devices.txt;
	done;
fi;

sh ./get.repos.sh

if [ -z "$1" ]; then
	sh ./build.cm.sh
	sh ./build.twrp.sh
elif [ "$1" == "cm" ]; then
	sh ./build.cm.sh
elif [ "$1" == "twrp" ]; then
	sh ./build.twrp.sh
fi;

sh ./copy.files.sh

cd ${OLDPWD}

