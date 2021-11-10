#!/bin/bash

# repo parameters
IFS='/'; BINDER_PARAMS=(${BINDER_REF_URL}); unset IFS;
PROVIDER_NAME=${BINDER_PARAMS[-5]}
USER_NAME=${BINDER_PARAMS[-4]}
REPO_NAME=${BINDER_PARAMS[-3]}
COMMIT_REF=${BINDER_PARAMS[-1]}
# paths
CONFIG_FILE="content/_config.yml"
BOOK_DST_PATH="/mnt/books/${USER_NAME}/${PROVIDER_NAME}/${REPO_NAME}/${COMMIT_REF}"
BOOK_BUILT_FLAG="${BOOK_DST_PATH}/successfully_built"
BOOK_BUILD_LOG="${BOOK_DST_PATH}/book-build.log"

# checking if book build is necessary
echo "Checking if jupyter book build will be done..."
if [ -f "${CONFIG_FILE}" ]; then
  echo -e "\t ${CONFIG_FILE} exists."
else
  echo -e "\t ${CONFIG_FILE} not found."
  echo "Skipping jupyter-book build."
  exit 0
fi
if [ -f "${BOOK_BUILT_FLAG}" ]; then
  echo -e "\t ${BOOK_BUILT_FLAG} exists"
  echo "Skipping jupyter-book build."
  exit 0
else
  echo -e "\t ${BOOK_BUILT_FLAG} not found."
fi
# building jupyter book build
mkdir -p ${BOOK_DST_PATH}
touch ${BOOK_BUILD_LOG}
echo "Building jupyter-book for ${USER_NAME}/${PROVIDER_NAME}/${REPO_NAME}/${COMMIT_REF}"
mkdir -p ${BOOK_DST_PATH}
jupyter-book build --all --verbose --path-output ${BOOK_DST_PATH} content 2>&1 | tee ${BOOK_BUILD_LOG}
# https://stackoverflow.com/a/1221870
JB_EXIT_CODE=${PIPESTATUS[0]}
if [ ${JB_EXIT_CODE} -ne 0 ] ; then
  echo -e "Jupyter-book build failed!"
  exit 0
else
  echo "Taring book build artifacts..."
  tar -zcvf ${BOOK_DST_PATH}".tar.gz" ${BOOK_DST_PATH}
  touch ${BOOK_BUILT_FLAG}
fi