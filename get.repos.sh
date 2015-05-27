#!/bin/bash

if [ -z ${TOPBUILDDIR} ]; then
	echo "This script is not intended to be run directly."
	echo "Please run \"build.all.sh\".";
	exit 1;
fi;

MANIFESTDIR=${TOPBUILDDIR}/scripts/manifests
CMDIR=${TOPBUILDDIR}/cm
CMBRANCH="cm-12.1"
TWRPDIR=${TOPBUILDDIR}/omni_min
TWRPBRANCH="android-5.1"

if [ ! -d ${CMDIR} ]; then
	echo "Downloading CM Repo";
	mkdir ${CMDIR};
	cd ${CMDIR};
	repo init -u git://github.com/CyanogenMod/android.git -b ${CMBRANCH}
	mkdir -p ${CMDIR}/.repo/local_manifests
	cp ${MANIFESTDIR}/cm/*.xml ${CMDIR}/.repo/local_manifests/
	repo sync -j5
fi;

if [ ! -d ${TWRPDIR} ]; then
	echo "Downloading TWRP Repo";
	mkdir ${TWRPDIR};
	cd ${TWRPDIR};
	repo init -u git://github.com/notyal/twrp_recovery_manifest.git -b ${TWRPBRANCH}
	mkdir -p ${TWRPDIR}/.repo/local_manifests
	cp ${MANIFESTDIR}/omni/*.xml ${TWRPDIR}/.repo/local_manifests/
	sed -i '/recovery/d' ${TWRPDIR}/.repo/manifest.xml
	repo sync -j5
fi;
