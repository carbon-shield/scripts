#!/bin/sh

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

cd ${BASEDIR}
for dev in "shieldtablet"
do
	lunch full_${dev}-${BUILDTYPE}
	make -j9 recoveryimage multirom_zip
done

# Special handling
while read -r patch pdir; do
	echo Applying ${patch};
	cd ${BASEDIR}/${pdir};
	git apply ${PATCHDIR}/${patch}.patch
done < ${PATCHDIR}/patches_twrp_special.txt;

cd ${BASEDIR}
for dev in "roth"
do
	lunch full_${dev}-${BUILDTYPE}
	make -j9 recoveryimage multirom_zip
done

# Revert special handling
tempvar=$(tac ${PATCHDIR}/patches_twrp_special.txt);
while read -r patch pdir; do
	echo Reverting ${patch};
	cd ${BASEDIR}/${pdir};
	git apply -R ${PATCHDIR}/${patch}.patch
done <<< "${tempvar}";

# Revert patches
tempvar=$(tac ${PATCHDIR}/patches_twrp.txt);
while read -r patch pdir; do
	echo Reverting ${patch};
	cd ${BASEDIR}/${pdir};
	git apply -R ${PATCHDIR}/${patch}.patch
done <<< "${tempvar}";

cd ${OLD_PWD}

