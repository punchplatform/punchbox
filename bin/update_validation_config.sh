#!/bin/bash -u
# This script will update your validation configuration inside the pp-punchbox subfolders,
# based on a provided standalone setup archive that contains this tenants/robots configuration

# ------- Prerequisites

function fatal () {
	echo "FATAL ERROR in $0: $*" 1>&2
	exit 1 
}

which unzip 1>/dev/null || fatal "'unzip' command is needed by '$0'. Please install it and try again."
if [ -n "${PUNCHBOX_DIR:-}" ] && [ -d "${PUNCHBOX_DIR}" ] ; then
	cd "${PUNCHBOX_DIR}" 
fi

# ------- Get Standalone location 

STANDALONE_POINTER_FILE="${PUNCHBOX_DIR}/.standalone_archive"
if [ -e "${STANDALONE_POINTER_FILE}" ] ; then
	STANDALONE_ARCHIVE="$(cat ${STANDALONE_POINTER_FILE})"
fi

if ! [ -e "${STANDALONE_ARCHIVE:-}" ] ; then
		read -e -p "Path to standalone setup archive: " -i "${STANDALONE_ARCHIVE:-}" STANDALONE_ARCHIVE
fi

if ! [ -e "${STANDALONE_ARCHIVE}" ] ; then
	rm -f "${STANDALONE_POINTER_FILE}"
	fatal "Could not find standalone archive in '${STANDALONE_ARCHIVE}'. Please configure path in '${STANDALONE_POINTER_FILE} and/or run '$0' again..." 
fi

# ------- Extract conf

echo "Retrieving validation configuration from standalone archive : '${STANDALONE_ARCHIVE}' ..."

TEMP_EXTRACTDIR=$(mktemp -d -t punchbox-configuration-fetching.XXXXXXX)

unzip -d "${TEMP_EXTRACTDIR}" "${STANDALONE_ARCHIVE}" '*/conf/tenants/*' '*/conf/resources/*' 1>/dev/null || fatal "Unable to unzip validation configuration from '${STANDALONE_ARCHIVE}' standalone archive."

# ------- Copy conf

VALIDATION_CONF_SOURCEDIR="$(ls -d "${TEMP_EXTRACTDIR}"/*/conf)"

[ -d "${VALIDATION_CONF_SOURCEDIR}" ] || fatal "Could not find 'conf' subdirectory inside standalone archive '${STANDALONE_ARCHIVE}'"

# We change the elasticsearch shards number to 2
find "${VALIDATION_CONF_SOURCEDIR}"/resources/elasticsearch/templates -type f  | xargs sed -i '/shards/s/1/2/g' || fatal "Could not adapt shards count in elasticsearch templates"

VALIDATION_REFDIR=${PUNCHBOX_DIR}/punch/configurations/validation

[ -d "${VALIDATION_REFDIR}" ] || fatal "Target validation configuration reference dir not found in your punchbox tree. Expected it here: '${VALIDATION_REFDIR}'."

cp -r "${VALIDATION_CONF_SOURCEDIR}"/* "${VALIDATION_REFDIR}" || fatal "could not copy reference validation configuration from '${VALIDATION_CONF_SOURCEDIR}/*' to '${VALIDATION_REFDIR}' "

# ------- Clean

rm -rf "${TEMP_EXTRACTDIR}"

echo "${STANDALONE_ARCHIVE}" > "${STANDALONE_POINTER_FILE}"
