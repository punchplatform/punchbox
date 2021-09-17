#!/bin/bash -u
# This script will update your validation configuration inside the pp-punchbox subfolders,
# based on a provided standalone setup archive that contains this tenants/robots configuration

# The archive location will try to be deduced from the configured deployer.

# If unfound, the user will be prompted to locate the standalone archive

function fatal () {
	echo "FATAL ERROR in $0: $*" 1>&2
	exit 1 
}


which unzip 1>/dev/null || fatal "'unzip' command is needed by '$0'. Please install it and try again."

if [ -n "${PUNCHBOX_DIR:-}" ] && [ -d "${PUNCHBOX_DIR}" ] ; then
	
	cd "${PUNCHBOX_DIR}" 
fi



# Are we in a punchbox dir with an already declared deployer ?
[ -e .deployer ] || fatal "please configure your punchbox environment using 'make configure-deployer' and try again after activating your environment using 'source ./activate.sh'."

. activate.sh

DEPLOYER_ARCHIVE="$(cat .deployer)"

[ -e "${DEPLOYER_ARCHIVE}" ] || fatal "Deployer archive nout found. Please configure your punchbox environment using 'make configure-deployer' and try again after activating your environment using 'source ./activate.sh'."


STANDALONE_POINTER_FILE="${PUNCHBOX_DIR}/.standalone_archive"

if [ -e "${STANDALONE_POINTER_FILE}" ] ; then
	STANDALONE_ARCHIVE="$(cat ${STANDALONE_POINTER_FILE})"
fi

if ! [ -e "${STANDALONE_ARCHIVE:-}" ] ; then

	if [ -z "${STANDALONE_ARCHIVE:-}" ] ; then
		# No idea where the standalone archive is ? Try guessing from the deployer archive location...
		STANDALONE_ARCHIVE="$(sed -e 's/punch-deployer/punch-standalone/g' -e 's/\.zip/-linux.zip/g' <<< "${DEPLOYER_ARCHIVE}")"
		[ -e "${STANDALONE_ARCHIVE}" ] && echo "Inferred standalone archive location from deployer archive location."
	fi

	if ! [ -e "${STANDALONE_ARCHIVE:-}" ] ; then
		read -e -p "Path to standalone setup archive: " -i "${STANDALONE_ARCHIVE:-}" STANDALONE_ARCHIVE
	fi

fi

if ! [ -e "${STANDALONE_ARCHIVE}" ] ; then
	rm -f "${STANDALONE_POINTER_FILE}"
	fatal "Could not find standalone archive in '${STANDALONE_ARCHIVE}'. Please configure path in '${STANDALONE_POINTER_FILE} and/or run '$0' again..." 
fi

echo "Retrieving validation configuration from standalone archive : '${STANDALONE_ARCHIVE}' ..."

TEMP_EXTRACTDIR=$(mktemp -d -t punchbox-configuration-fetching.XXXXXXX)

unzip -d "${TEMP_EXTRACTDIR}" "${STANDALONE_ARCHIVE}" '*/conf/tenants/*' '*/conf/resources/*' 1>/dev/null || fatal "Unable to unzip validation configuration from '${STANDALONE_ARCHIVE}' standalone archive."


VALIDATION_CONF_SOURCEDIR="$(ls -d "${TEMP_EXTRACTDIR}"/*/conf)"

[ -d "${VALIDATION_CONF_SOURCEDIR}" ] || fatal "Could not find 'conf' subdirectory inside standalone archive '${STANDALONE_ARCHIVE}'"

# We change the elasticsearch shards number to 2
find "${VALIDATION_CONF_SOURCEDIR}"/resources/elasticsearch/templates -type f  | xargs sed -i '/shards/s/1/2/g' || fatal "Could not adapt shards count in elasticsearch templates"

# For compatibility with legacy punchbox code related to elastalert (in case no rules are present in punchbox config)
mkdir -p "${VALIDATION_CONF_SOURCEDIR}"/tenants/validation/channels/elastalert_validation/rules

VALIDATION_REFDIR=${PUNCHBOX_DIR}/punch/configurations/validation

[ -d "${VALIDATION_REFDIR}" ] || fatal "Target validation configuration reference dir not found in your punchbox tree. Expected it here: '${VALIDATION_REFDIR}'."

#rm -rf "${VALIDATION_REFDIR}"/* || fatal "Could not cleanup previous content of validation reference dir at : '${VALIDATION_REFDIR}'"


#echo 'mv "'${VALIDATION_CONF_SOURCEDIR}/tenants'" "'${VALIDATION_REFDIR}'"'
cp -r "${VALIDATION_CONF_SOURCEDIR}"/* "${VALIDATION_REFDIR}" || fatal "could not copy reference validation configuration from '${VALIDATION_CONF_SOURCEDIR}/*' to '${VALIDATION_REFDIR}' "

rm -rf "${TEMP_EXTRACTDIR}"

echo "${STANDALONE_ARCHIVE}" > "${STANDALONE_POINTER_FILE}"
