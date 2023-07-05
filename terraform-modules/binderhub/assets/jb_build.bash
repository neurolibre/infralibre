#!/bin/bash

# repo parameters
IFS='/'; BINDER_PARAMS=(${BINDER_REF_URL}); unset IFS;
PROVIDER_NAME=${BINDER_PARAMS[-5]}
USER_NAME=${BINDER_PARAMS[-4]}
REPO_NAME=${BINDER_PARAMS[-3]}
COMMIT_REF=${BINDER_PARAMS[-1]}
# paths
CONFIG_FILE="content/_config.yml"
NEUROLIBRE_CUSTOM="content/_neurolibre.yml"
BOOK_DST_PATH="/mnt/books/${USER_NAME}/${PROVIDER_NAME}/${REPO_NAME}/${COMMIT_REF}"
BOOK_BUILT_FLAG="${BOOK_DST_PATH}/successfully_built"
BOOK_BUILD_LOG="${BOOK_DST_PATH}/book-build.log"
BINDERHUB_URL="https://test.conp.cloud"
BOOK_CACHE_PATH=${BOOK_DST_PATH}"/_build/.jupyter_cache"

extract_yaml_field() {
  local yaml_file="$1"
  local field_name="$2"
  if [ -f "$yaml_file" ]; then
    local field_value=$(sed -n "s/^[[:blank:]]*${field_name}:[[:blank:]]*\(.*\)/\1/p" "$yaml_file")
    field_value=$(sed 's/^"\(.*\)"$/\1/' <<< "$field_value")
    field_value=$(sed 's/[[:space:]]//g' <<< "$field_value")
    echo "$field_value"
  else
    echo "YAML file not found: $yaml_file"
  fi
}

# checking if book build is necessary
echo "Checking if the book will be built..." 2>&1 | tee ${BOOK_BUILD_LOG}
if [ -f "${CONFIG_FILE}" ]; then
  echo -e "\t ${CONFIG_FILE} exists." 2>&1 | tee -a ${BOOK_BUILD_LOG}
else
  echo -e "\t ${CONFIG_FILE} not found." 2>&1 | tee -a ${BOOK_BUILD_LOG}
  echo "Skipping jupyter-book build." 2>&1 | tee -a ${BOOK_BUILD_LOG}
  exit 0
fi
if [ -f "${BOOK_BUILT_FLAG}" ]; then
  echo -e "\t ${BOOK_BUILT_FLAG} exists" 2>&1 | tee -a ${BOOK_BUILD_LOG}
  echo "Skipping jupyter-book build." 2>&1 | tee -a ${BOOK_BUILD_LOG}
  exit 0
else
  echo -e "\t ${BOOK_BUILT_FLAG} not found." 2>&1 | tee -a ${BOOK_BUILD_LOG}
fi
if git log -1 | grep "neurolibre-debug"; then
    echo "Bypassing jupyter-book build as requested by the user (neurolibre-debug)" 2>&1 | tee -a ${BOOK_BUILD_LOG}
    exit 0
fi
# changing config if test submission
if [[ ${USER_NAME} != "roboneurolibre" ]] ; then
  echo -e "\t Detecting user submission, changing launch_button config to test ${BINDERHUB_URL} and adding jb cache execution." 2>&1 | tee -a ${BOOK_BUILD_LOG}
  # updating binderhub_url if exists, or adding it
  if grep ${CONFIG_FILE} -e binderhub_url; then
    echo "detect existing binderhub_url" 2>&1 | tee -a ${BOOK_BUILD_LOG}
    sed -i "/binderhub_url/c\  binderhub_url             : "${BINDERHUB_URL} ${CONFIG_FILE}
  else
    cat << EOF >> ${CONFIG_FILE}
    
launch_buttons:
  binderhub_url: "${BINDERHUB_URL}"
EOF
  fi
  cat << EOF >> ${CONFIG_FILE}

execute:
  execute_notebooks         : "cache"  # Whether to execute notebooks at build time. Must be one of ("auto", "force", "cache", "off")
  # NOTE: The cache location below means that this book MUST be built from the parent directory, not within content/.
  cache                     : "${BOOK_CACHE_PATH}"  # A path to the jupyter cache that will be used to store execution artifacts. Defaults to "_build/.jupyter_cache/"
  exclude_patterns          : []  # A list of patterns to *skip* in execution (e.g. a notebook that takes a really long time)
  timeout                   : -1  # remove restriction on execution time
EOF
fi


if [ -f "$NEUROLIBRE_CUSTOM" ]; then
    BOOK_LAYOUT=$(extract_yaml_field "$NEUROLIBRE_CUSTOM" "book_layout")
    SINGLE_PAGE=$(extract_yaml_field "$NEUROLIBRE_CUSTOM" "single_page")
  else
    echo "YAML file not found: $yaml_file"
fi


# building jupyter book
echo "" 2>&1 | tee -a ${BOOK_BUILD_LOG}
echo "Build source: ${USER_NAME}/${PROVIDER_NAME}/${REPO_NAME}/${COMMIT_REF}" 2>&1 | tee -a ${BOOK_BUILD_LOG}
echo "" 2>&1 | tee -a ${BOOK_BUILD_LOG}
mkdir -p ${BOOK_DST_PATH}
mkdir -p ${BOOK_CACHE_PATH}
touch ${BOOK_BUILD_LOG}
# Write the first line to the log
echo "" 2>&1 | tee -a ${BOOK_BUILD_LOG}

if [ "$BOOK_LAYOUT" = "traditional" ]; then
    # SINGLE_PAGE exists when BOOK_LAYOUT is traditional (documentation)
    echo -e "Customized book build: traditional paper layout based on ${SINGLE_PAGE}" 2>&1 | tee -a ${BOOK_BUILD_LOG}
    jupyter-book build --all --verbose --path-output ${BOOK_DST_PATH} --builder singlehtml content/${SINGLE_PAGE} 2>&1 | tee -a ${BOOK_BUILD_LOG}
  else
    # Use default build otherwise
    jupyter-book build --all --verbose --path-output ${BOOK_DST_PATH} content 2>&1 | tee -a ${BOOK_BUILD_LOG}
fi

# https://stackoverflow.com/a/1221870
JB_EXIT_CODE=${PIPESTATUS[0]}
# checking execution
if grep ${BOOK_BUILD_LOG} -e "Execution Failed"; then
  echo -e "Jupyter-book execution failed!" 2>&1 | tee -a ${BOOK_BUILD_LOG}
  exit 0
fi
echo "Jupyter-book exit code:" $JB_EXIT_CODE 2>&1 | tee -a ${BOOK_BUILD_LOG}
if [ ${JB_EXIT_CODE} -ne 0 ] ; then
  echo -e "Jupyter-book build failed!" 2>&1 | tee -a ${BOOK_BUILD_LOG}
  exit 0
else
  echo "Compressing book build artifacts..." 2>&1 | tee -a ${BOOK_BUILD_LOG}
  tar -zcvf ${BOOK_DST_PATH}".tar.gz" ${BOOK_DST_PATH} 2>&1 | tee -a ${BOOK_BUILD_LOG}
  touch ${BOOK_BUILT_FLAG}
  echo "Saving metadata for current submission..." 2>&1 | tee -a ${BOOK_BUILD_LOG}
  /bin/bash /usr/local/share/fill_submission_metadata.bash
fi