# Initializes various variables used by the script
SetVars () {
	# Find top level working directory
	SOURCE="${1}";
	while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
		TOPBUILDDIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )";
		SOURCE="$(readlink "$SOURCE")";
		[[ $SOURCE != /* ]] && SOURCE="$TOPBUILDDIR/$SOURCE"; # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
	done;
	TOPBUILDDIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )";
	TOPBUILDDIR="$(dirname "${TOPBUILDDIR}")";

	# Set relevant global variables
	MANIFESTDIR=${TOPBUILDDIR}/scripts/manifests;
	CMDIR=${TOPBUILDDIR}/cm;
	CMBRANCH="cm-12.1";
	TWRPDIR=${TOPBUILDDIR}/omni_min;
	TWRPBRANCH="android-5.1";
	PATCHDIR=${TOPBUILDDIR}/scripts/patches;
	ORIGPATH="${PATH}"

	# Set list of devices if not already set
	if [ ! -f ${TOPBUILDDIR}/scripts/devices.txt ]; then
		declare -a BUILDDEVICES=("roth" "shieldtablet" "foster");
		for dev in "${BUILDDEVICES[@]}"
		do
			echo ${dev} >> ${TOPBUILDDIR}/scripts/devices.txt;
		done;
	fi;
}

# Start up error checking
ValidityCheck () {
	# Check parameter validity
	if [ ! -z "$2" ] && [ ! "$2" == "cm" ] && [ ! "$2" == "twrp" ] && [ ! "$2" == "all" ]; then
		echo "Usage: $1 [cm OR twrp]";
		return 1;
	fi;

	# Check for needed programs
	command -v repo >/dev/null 2>&1 || { echo >&2 "repo is required, but not installed. Aborting."; return 1; }
	command -v abootimg >/dev/null 2>&1 || { echo >&2 "abootimg is required, but not installed. Aborting."; return 1; }

	return 0;
}

# Apply or revert a single patch
ApplyPatch () {
	REVERT=
	if [ "$1" == "revert" ]; then 
		REVERT="-R";
		shift;
	fi;

	if [ -d ${2} ] && [ -f ${1} ]; then
		cd ${2};
		git apply ${REVERT} ${1};
		return $?;
	else
		return 1;
	fi;
}

# Revert a set of patches listed in a given file
RevertPatchesFromFile () {
	if [ -f ${PATCHDIR}/${1} ]; then
		ERRORPATCH=${3};
		tempvar=$(tac ${PATCHDIR}/${1});
		while read -r patch pdir; do
			# If reverting due to an error, skip everything up to the cause of the error
			if [ -n "${ERRORPATCH}" ]; then
				if [ "${ERRORPATCH}" == "${patch}" ]; then
					ERRORPATCH=;
				fi;
				continue;
			fi;
			logadd "Reverting ${patch}";
			ApplyPatch revert ${PATCHDIR}/${patch}.patch ${2}/${pdir};
		done <<< "${tempvar}";
	fi;

	return 0;
}

# Apply a set of patches listed in a given file. If one errors, roll back previous patches.
ApplyPatchesFromFile () {
	if [ -f ${PATCHDIR}/${1} ]; then
		ERRORPATCH=;
		while read -r patch pdir; do
			logadd "Applying ${patch}";
			if ! ApplyPatch ${PATCHDIR}/${patch}.patch ${2}/${pdir}; then
				ERRORPATCH=${patch};
				break;
			fi;
		done < ${PATCHDIR}/${1};

		if [ -n "${ERRORPATCH}" ]; then
			logadd "Error applying ${patch}, reverting all grouped patches";
			RevertPatchesFromFile ${1} ${2} ${ERRORPATCH};
			return 1;
		fi;
	fi;

	return 0;
}

# Build the system
build_android () {
	# Name the parameters
	BUILDSYSTEM=${1};
	BASEDIR=${2};
	BUILDTYPE=${3};

	# Set what gets built based on system type
	if [ "${BUILDSYSTEM}" == "twrp" ]; then
		BUILDPREFIX="full";
		MAKETARGETS="recoveryimage multirom_zip";
	else
		BUILDPREFIX=${BUILDSYSTEM};
		MAKETARGETS="bacon";
	fi;

	logadd "Starting builds for ${BUILDSYSTEM}";

	# Save environment so it can be reset later
	saveenv;

	# Initialize the build system and clean previous builds
	cd ${BASEDIR};
	source build/envsetup.sh;
	export USE_CCACHE=1;
	export CCACHE_DIR=${BASEDIR}/ccache;
	make clean;

	# Apply custom patches
	if ! ApplyPatchesFromFile patches_${BUILDSYSTEM}.txt ${BASEDIR}; then
		echo "Couldn't apply patches for ${BUILDSYSTEM}, skipping builds";
		return 1;
	fi;

	# Loop through devices to build
	while read -r dev; do
		logadd "Building ${dev}";
		# Check if device is valid
		if [ "$(ls -d ${BASEDIR}/device/*/${dev} 2>/dev/null |wc -l)" == "0" ]; then
			echo "Couldn't find device tree for ${dev}, skipping";
			continue;
		fi;

		# Apply special handling patches, if needed
		if ! ApplyPatchesFromFile patches_${BUILDSYSTEM}_${dev}.txt ${BASEDIR}; then
			echo "Failed to apply some patches for ${dev}, skipping";
			continue;
		fi;

		# Build
		cd ${BASEDIR};
		lunch ${BUILDPREFIX}_${dev}-${BUILDTYPE};
		make -j9 ${MAKETARGETS};

		# Multirom Manager reads the TWRP recovery header to determine build info. This isn't inserted by the build system...
		if [ "${BUILDSYSTEM}" == "twrp" ]; then
			BDATE=$(basename ${BASEDIR}/out/target/product/${dev}/multirom-*-UNOFFICIAL-${dev}.zip |awk -F '[-]' '{ print $2 }');
			abootimg -u ${BASEDIR}/out/target/product/${dev}/recovery.img -c "name=mrom${BDATE}-01";
		fi;

		# Revert special handling, if needed
		RevertPatchesFromFile patches_${BUILDSYSTEM}_${dev}.txt ${BASEDIR};
	done < ${TOPBUILDDIR}/scripts/devices.txt;

	# Revert custom patches
	RevertPatchesFromFile patches_${BUILDSYSTEM}.txt ${BASEDIR};

	# Restore environment so it won't conflict with a different android build system
	resetenv;
}

# Update or init CM, switching branches if necessary
update_cm () {
	# Detect if the repo needs (re)initialized. This can be due to the folder not existing or not matching the branch this script expects.
	REPOINIT="false";
	if [ ! -d ${CMDIR} ]; then
		mkdir ${CMDIR};
		REPOINIT="true";
	else
		cd ${CMDIR}
		if [ "$(repo info manifest |grep merge |awk '{ print $4 }' |awk -F'/' '{ print $3 }')" != "${CMBRANCH}" ]; then
			REPOINIT="true";
		fi;
	fi;
	cd ${CMDIR};
	if [ "${REPOINIT}" == "true" ]; then
		logadd "(Re)Initializing CM repo";
		repo init -u git://github.com/CyanogenMod/android.git -b ${CMBRANCH};
	fi;

	# Update the repo
	logadd "Updating CM Repo";
	mkdir -p ${CMDIR}/.repo/local_manifests;
	cp ${MANIFESTDIR}/cm/*.xml ${CMDIR}/.repo/local_manifests/;
	repo sync -j5;
}

# Update or init OMNI, switching branches if necessary
update_twrp () {
	# Detect if the repo needs (re)initialized. This can be due to the folder not existing or not matching the branch this script expects.
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
		logadd "(Re)Initializing TWRP repo";
		repo init -u git://github.com/notyal/twrp_recovery_manifest.git -b ${TWRPBRANCH};
	fi;

	# Update the repo
	logadd "Updating TWRP Repo";
	mkdir -p ${TWRPDIR}/.repo/local_manifests;
	cp ${MANIFESTDIR}/omni/*.xml ${TWRPDIR}/.repo/local_manifests/;
	repo sync -j5;
}

# Main repo update function. Calls the specifc ones based on the requested build.
update_repos () {
	if [ -z $1 ] || [ "$1" == "all" ]; then
		update_cm;
		update_twrp;
	elif [ "$1" == "cm" ]; then
		update_cm;
	elif [ "$1" == "twrp" ]; then
		update_twrp;
	fi;
}

# Copy output files to a more unified location
copy_outputs () {
	# Local variables
	CM_OUT_DIR=${CMDIR}/out/target/product;
	TWRP_OUT_DIR=${TWRPDIR}/out/target/product;
	ORIGTZ=${TZ};
	TZ=UTC;
	UPLOAD_DIR=${TOPBUILDDIR}/uploads/$(date +%Y%m%d);
	TZ=${ORIGTZ};

	logadd "Copying output files";

	mkdir -p ${UPLOAD_DIR};
	cp ${TOPBUILDDIR}/scripts/build.log ${UPLOAD_DIR}/
	while read -r dev; do
		# Check if device is valid
		if [ "$(ls -d ${BASEDIR}/device/*/${dev} 2>/dev/null |wc -l)" == "0" ]; then
			continue;
		fi;

		# Copy files. Ignore types that weren't built.
		mkdir -p ${UPLOAD_DIR}/${dev};
		if [ -z $1 ] || [ "$1" == "cm" ]; then
			cp ${CM_OUT_DIR}/${dev}/cm-12*-UNOFFICIAL-${dev}.zip ${UPLOAD_DIR}/${dev}/;
		fi;
		if [ -z $1 ] || [ "$1" == "twrp" ]; then
			BDATE=$(basename ${TWRP_OUT_DIR}/${dev}/multirom-*-UNOFFICIAL-${dev}.zip |awk -F '[-]' '{ print $2 }');
			cp ${TWRP_OUT_DIR}/${dev}/multirom-*-UNOFFICIAL-${dev}.zip ${UPLOAD_DIR}/${dev}/;
			cp ${TWRP_OUT_DIR}/${dev}/recovery.img ${UPLOAD_DIR}/${dev}/twrp-multirom-${BDATE}-UNOFFICIAL-${dev}.img;
		fi;
	done < ${TOPBUILDDIR}/scripts/devices.txt;
}

# Simple logging function to output to screen and save to log
logadd () {
	LOGPATH="${TOPBUILDDIR}/scripts/build.log"
	if [ "$1" == "reset" ]; then
		rm -f "${LOGPATH}";
		shift;
	fi;
	echo "$(date +"%Y/%m/%d %H:%M:%S") - ${1}" |tee -a "${LOGPATH}";
}

# Save environment variables and functions
saveenv () {
	env |awk -F'=' '{ print $1 }' > ${TOPBUILDDIR}/scripts/before.env;
	declare -F |awk '{ print $3 }' > ${TOPBUILDDIR}/scripts/before.func;
}

# Restore environment variables and functions
# This compares what was saved above with what exists now and removes the extras
# PATH is set specifically because it's the only known modified variable, all others are just added
resetenv () {
	env |awk -F'=' '{ print $1 }' > ${TOPBUILDDIR}/scripts/after.env;
	declare -F |awk '{ print $3 }' > ${TOPBUILDDIR}/scripts/after.func;
	for delenv in $(comm -13 <(sort ${TOPBUILDDIR}/scripts/before.env) <(sort ${TOPBUILDDIR}/scripts/after.env)); do
		unset "${delenv}";
	done;
	for delfunc in $(comm -13 <(sort ${TOPBUILDDIR}/scripts/before.func) <(sort ${TOPBUILDDIR}/scripts/after.func)); do
		unset -f "${delfunc}";
	done;
	PATH="${ORIGPATH}";
	rm -f ${TOPBUILDDIR}/scripts/*.{env,func}
}
