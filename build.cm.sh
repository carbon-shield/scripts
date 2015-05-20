#!/bin/sh

OLD_PWD=$(pwd)
BASEDIR=${TOPBUILDDIR}/cm
PATCHDIR=${TOPBUILDDIR}/scripts/patches
BUILDTYPE=userdebug
declare -a BUILDDEVICES=("roth" "shieldtablet")

cd ${BASEDIR}
repo sync -j5

source build/envsetup.sh
export USE_CCACHE=1
export CCACHE_DIR=${BASEDIR}/ccache
make clean

# Apply custom patches
while read -r patch pdir; do
	echo Applying ${patch};
	cd ${BASEDIR}/${pdir};
	git apply ${PATCHDIR}/${patch}.patch;
done < ${PATCHDIR}/patches_cm.txt;

cd ${BASEDIR}
for dev in "${BUILDDEVICES[@]}"
do
	lunch cm_${dev}-${BUILDTYPE}
	make -j9 bacon
done

# Revert custom patches
tempvar=$(tac ${PATCHDIR}/patches_cm.txt);
while read -r patch pdir; do
	echo Reverting ${patch};
	cd ${BASEDIR}/${pdir};
	git apply -R ${PATCHDIR}/${patch}.patch;
done <<< "${tempvar}";

cd ${OLD_PWD}
