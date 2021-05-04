export PUNCHBOX_DIR=/home/lca/Projects/punch/punchbox
export PUNCHBOX_BUILD_DIR="${PUNCHBOX_DIR}/punch/build"
export PUNCHPLATFORM_CONF_DIR="${PUNCHBOX_BUILD_DIR}"/pp-conf
export PATH="${PUNCHBOX_DIR}/bin:${PUNCHBOX_DIR}/bin/pex/ansible_pex:$PATH"
export PS1='\[[1;32m\]punchbox:\[[0m\][\W]$ '
mkdir -p "${PUNCHBOX_BUILD_DIR}"

# Looking for unziped deployer (if it exists)
export PUNCHBOX_DEPLOYER_DIR=""
for deployer in $(cd "${PUNCHBOX_BUILD_DIR}" ; ls -ltrd */ 2>null | grep 'punch.*-deployer-.*' 2>null) ; do
   PUNCHBOX_DEPLOYER_DIR="${PUNCHBOX_BUILD_DIR}/${deployer}"
done

if [ "${PUNCHBOX_DEPLOYER_DIR:-}" = ""  ] ; then
	echo "No deployer unzipped."
else
	echo "Using deployer '${PUNCHBOX_DEPLOYER_DIR}'..."
	export PATH="${PUNCHBOX_DEPLOYER_DIR}/bin:${PATH}"
fi

