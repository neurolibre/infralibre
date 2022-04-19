#!/bin/bash

# paths
LOOKUP_TABLE_PATH="/mnt/data/book-artifacts/lookup_table.tsv"
DATA_REQ_PATH="/home/jovyan/binder/data_requirement.json"

# create lookup table if doe snot exists
if [ ! -f "${LOOKUP_TABLE_PATH}" ]; then
    mkdir -p "${LOOKUP_TABLE_PATH%/*}" && touch $LOOKUP_TABLE_PATH
    echo "date,repository_url,docker_img,data_project_name,data_url,data_doi" >> $LOOKUP_TABLE_PATH
fi
# checking if repo2data is used
PROJECT_NAME=""
DATA_URL=""
if [ -f "${DATA_REQ_PATH}" ]; then
    PROJECT_NAME=$(cat $DATA_REQ_PATH | python -c 'import json,sys; key="projectName"; obj=json.load(sys.stdin); curr_key=obj[key] if key in obj.keys() else ""; print(curr_key)')
    DATA_URL=$(cat $DATA_REQ_PATH | python -c 'import json,sys; key="src"; obj=json.load(sys.stdin); curr_key=obj[key] if key in obj.keys() else ""; print(curr_key)')
    DOI=$(cat $DATA_REQ_PATH | python -c 'import json,sys; key="doi"; obj=json.load(sys.stdin); curr_key=obj[key] if key in obj.keys() else ""; print(curr_key)')
fi
# if submission (repo) already exists, update, otherwise append
SUBMISSION_METADATA="$(date),$BINDER_REPO_URL,$JUPYTER_IMAGE_SPEC,$PROJECT_NAME,$DATA_URL,$DOI"
if grep ${LOOKUP_TABLE_PATH} -e $BINDER_REPO_URL; then
    #replace
    sed -i "s|.*$BINDER_REPO_URL.*|$SUBMISSION_METADATA|" $LOOKUP_TABLE_PATH > /dev/null 2>&1
else
    echo $SUBMISSION_METADATA >> $LOOKUP_TABLE_PATH
fi
