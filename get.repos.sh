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

# Update or init CM, switching branches if necessary
if [ -z $1 ] || [ "$1" == "cm" ]; then
	REPOINIT="false";
	if [ ! -d ${CMDIR} ]; then
		mkdir ${CMDIR};
		REPOINIT="true";
	else
		cd ${CMDIR}
		if [ "$(repo info manifest |grep merge |awk '{ print $4 }')" != "${CMBRANCH}" ]; then
			REPOINIT="true";
		fi;
	fi;
	cd ${CMDIR};
	if [ "${REPOINIT}" == "true" ]; then
		repo init -u git://github.com/CyanogenMod/android.git -b ${CMBRANCH}
	fi;
	echo "Updating CM Repo";
	mkdir -p ${CMDIR}/.repo/local_manifests
	cp ${MANIFESTDIR}/cm/*.xml ${CMDIR}/.repo/local_manifests/
	repo sync -j5
fi;

# Update or init OMNI, switching branches if necessary
if [ -z $1 ] || [ "$1" == "twrp" ]; then
	REPOINIT="false";
	if [ ! -d ${TWRPDIR} ]; then
		mkdir ${TWRPDIR};
		REPOINIT="true";
	else
		cd ${TWRPDIR}
		if [ "$(repo info manifest |grep merge |awk '{ print $4 }' |awk -F'/' '{ print $3 }')" != "${TWRPBRANCH}" ]; then
			REPOINIT="true";
		fi;
	fi;
	cd ${TWRPDIR};
	if [ "${REPOINIT}" == "true" ]; then
		repo init -u git://github.com/notyal/twrp_recovery_manifest.git -b ${TWRPBRANCH}
	fi;
	echo "Updating TWRP Repo";
	mkdir -p ${TWRPDIR}/.repo/local_manifests
	cp ${MANIFESTDIR}/omni/*.xml ${TWRPDIR}/.repo/local_manifests/
	repo sync -j5
fi;
