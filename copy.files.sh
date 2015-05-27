#!/bin/bash

if [ -z ${TOPBUILDDIR} ]; then
	echo "This script is not intended to be run directly."
	echo "Please run \"build.all.sh\".";
	exit 1;
fi;

CM_OUT_DIR=${TOPBUILDDIR}/cm/out/target/product
TWRP_OUT_DIR=${TOPBUILDDIR}/omni_min/out/target/product
UPLOAD_DIR=${TOPBUILDDIR}/uploads/$(date +%Y%m%d)

mkdir -p ${UPLOAD_DIR}
while read -r dev; do
	mkdir -p ${UPLOAD_DIR}/${dev}
	cp ${CM_OUT_DIR}/${dev}/cm-12*-UNOFFICIAL-${dev}.zip ${UPLOAD_DIR}/${dev}/;
	BDATE=$(basename ${TWRP_OUT_DIR}/${dev}/multirom-*-UNOFFICIAL-${dev}.zip |awk -F '[-]' '{ print $2 }');
	cp ${TWRP_OUT_DIR}/${dev}/multirom-*-UNOFFICIAL-${dev}.zip ${UPLOAD_DIR}/${dev}/;
	cp ${TWRP_OUT_DIR}/${dev}/recovery.img ${UPLOAD_DIR}/${dev}/twrp-multirom-${BDATE}-UNOFFICIAL-${dev}.img;
done < ${TOPBUILDDIR}/scripts/devices.txt;
