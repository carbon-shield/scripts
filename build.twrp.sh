#!/bin/bash

if [ -z ${TOPBUILDDIR} ]; then
	echo "This script is not intended to be run directly."
	echo "Please run \"build.all.sh twrp\" to build only TWRP and MultiROM.";
	exit 1;
fi;

OLD_PWD=$(pwd)
BASEDIR=${TOPBUILDDIR}/omni_min
PATCHDIR=${TOPBUILDDIR}/scripts/patches
BUILDTYPE=userdebug

cd ${BASEDIR}
repo sync -j5

source build/envsetup.sh
export USE_CCACHE=1
export CCACHE_DIR=${BASEDIR}/ccache
make clean

# Apply patches
while read -r patch pdir; do
	echo Applying ${patch};
	cd ${BASEDIR}/${pdir};
	git apply ${PATCHDIR}/${patch}.patch
done < ${PATCHDIR}/patches_twrp.txt;

while read -r dev; do
	# Special handling, if needed
	if [ -f ${PATCHDIR}/patches_twrp_${dev}.txt ]; then
		while read -r patch pdir; do
			echo Applying ${patch};
			cd ${BASEDIR}/${pdir};
			git apply ${PATCHDIR}/${patch}.patch
		done < ${PATCHDIR}/patches_twrp_${dev}.txt;
	fi;

	# Build
	cd ${BASEDIR}
	lunch full_${dev}-${BUILDTYPE}
	make -j9 recoveryimage multirom_zip
	BDATE=$(basename ${BASEDIR}/out/target/product/${dev}/multirom-*-UNOFFICIAL-${dev}.zip |awk -F '[-]' '{ print $2 }');
	abootimg -u ${BASEDIR}/out/target/product/${dev}/recovery.img -c "name=mrom${BDATE}-01"

	# Revert special handling, if needed
	if [ -f ${PATCHDIR}/patches_twrp_${dev}.txt ]; then
		tempvar=$(tac ${PATCHDIR}/patches_twrp_${dev}.txt);
		while read -r patch pdir; do
			echo Reverting ${patch};
			cd ${BASEDIR}/${pdir};
			git apply -R ${PATCHDIR}/${patch}.patch
		done <<< "${tempvar}";
	fi;
done < ${TOPBUILDDIR}/scripts/devices.txt;

# Revert patches
tempvar=$(tac ${PATCHDIR}/patches_twrp.txt);
while read -r patch pdir; do
	echo Reverting ${patch};
	cd ${BASEDIR}/${pdir};
	git apply -R ${PATCHDIR}/${patch}.patch
done <<< "${tempvar}";

cd ${OLD_PWD}

