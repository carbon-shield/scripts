#!/bin/bash

if [ -z ${TOPBUILDDIR} ]; then
	echo "This script is not intended to be run directly."
	echo "Please run \"build.all.sh cm\" to build only CM.";
	exit 1;
fi;

OLD_PWD=$(pwd)
BASEDIR=${TOPBUILDDIR}/cm
PATCHDIR=${TOPBUILDDIR}/scripts/patches
BUILDTYPE=userdebug

cd ${BASEDIR}
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

while read -r dev; do
	# Special handling, if needed
	if [ -f ${PATCHDIR}/patches_cm_${dev}.txt ]; then
		while read -r patch pdir; do
			echo Applying ${patch};
			cd ${BASEDIR}/${pdir};
			git apply ${PATCHDIR}/${patch}.patch
		done < ${PATCHDIR}/patches_cm_${dev}.txt;
	fi;

	# Build
	cd ${BASEDIR}
	lunch cm_${dev}-${BUILDTYPE}
	make -j9 bacon

	# Revert special handling, if needed
	if [ -f ${PATCHDIR}/patches_cm_${dev}.txt ]; then
		tempvar=$(tac ${PATCHDIR}/patches_cm_${dev}.txt);
		while read -r patch pdir; do
			echo Reverting ${patch};
			cd ${BASEDIR}/${pdir};
			git apply -R ${PATCHDIR}/${patch}.patch
		done <<< "${tempvar}";
	fi;
done < ${TOPBUILDDIR}/scripts/devices.txt;

# Revert custom patches
tempvar=$(tac ${PATCHDIR}/patches_cm.txt);
while read -r patch pdir; do
	echo Reverting ${patch};
	cd ${BASEDIR}/${pdir};
	git apply -R ${PATCHDIR}/${patch}.patch;
done <<< "${tempvar}";

cd ${OLD_PWD}
