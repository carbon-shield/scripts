#!/bin/bash

# Store current working directory
OLDPWD=$(pwd);

source "${BASH_SOURCE%/*}/functions.sh"
if ! ValidityCheck $0 $1; then
	exit -1;
fi;
SetVars "${BASH_SOURCE[0]}"

logadd reset "Builds started";

update_repos $1;

if [ -z "$1" ] || [ "$1" == "all" ]; then
	build_android cm ${CMDIR} userdebug;
	build_android twrp ${TWRPDIR} userdebug;
elif [ "$1" == "cm" ]; then
	build_android cm ${CMDIR} userdebug;
elif [ "$1" == "twrp" ]; then
	build_android twrp ${TWRPDIR} userdebug;
fi;

copy_outputs $1;

logadd "Builds finished";

cd ${OLDPWD}
