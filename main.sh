#!/bin/bash

TARGET_YAML="./target.yaml"
SLEEP_UNTIL_SCRAPE=5
RESULT_DIR="html"
RESULT_FILE_HEADER="result_"
RESULT_FILE_FOOTER=".csv"

if [ ! -f ${TARGET_YAML} ]; then
  echo "ERROR: ${TARGET_YAML} not found" >&2
  exit 1
fi

echo -n "Scraping process will start, OK? [Y/n]: "
read YN
echo
case $YN in
  "" | [Yy]* )
    echo " - reset data"
    rm -rf ${RESULT_DIR}
    mkdir ${RESULT_DIR}
    echo " - start scraping"
    for l in `cat ${TARGET_YAML} | yq '.spot | @csv' | sed -e '1d'`; do
        spot=$(echo $l | cut -d',' -f1)
        url=$(echo $l | cut -d',' -f2)
        echo -n "   - get ${url}"
        curl -s "${url}" > ./${RESULT_DIR}/${spot}.html
        sleep ${SLEEP_UNTIL_SCRAPE}
        echo " ... done"
    done
    ;;
  * )
    if [ ! -d ${RESULT_DIR} ]; then
      echo "ERROR: ${RESULT_DIR} not found" >&2
      exit 1
    fi
    dirty=0
    for l in `cat ${TARGET_YAML} | yq '.spot | @csv' | sed -e '1d'`; do
        spot=$(echo $l | cut -d',' -f1)
        if [ ! -f ${RESULT_DIR}/${spot}.html ]; then
          echo "ERROR: ${RESULT_DIR}/${spot}.html not found" >&2
          dirty=1
        fi
    done
    if [ $dirty -ne 0 ]; then
        echo "ERROR: ${RESULT_DIR} has not all html file. you need re-scrape." >&2
        exit 1
    fi
    ;;
esac

for i in `seq 0 5`; do
    RESULT_FILE=${RESULT_FILE_HEADER}${i}${RESULT_FILE_FOOTER}
    rm -f ${RESULT_FILE}
    echo "name,address,tel,business_hours,url,spot" > ${RESULT_FILE}
    for html in `ls ./${RESULT_DIR}/${i}*.html`; do
        cat ${html} | grep '<p class="access">'  | while read line
        do
            spot=$(echo ${html} | cut -d'/' -f3 | cut -d'.' -f1,2)
            name=$(echo $line | gsed 's/.*<h3 class="name"><a href="[^"]*">\([^<]*\)<\/a><\/h3>.*/\1/')
            address=$(echo $line | gsed 's/<p class="access">\([^<]*\)<\/p>.*/\1/')
            tel=$(echo $line | gsed 's/.*<p class="comment">電話番号　\([^"]*\)<\/p>.*/\1/')
            url=$(echo $line | gsed 's/.*<h3 class="name"><a href="\([^"]*\)">[^<]*<\/a><\/h3>.*/\1/')
            business_hours=$(echo $line | gsed 's/.*<p class="comment">営業時間　\([^"]*\)<\/p>.*/\1/')
            echo "${name},${address},${tel},${business_hours},${url},${spot}"
            echo "${name},${address},${tel},${business_hours},${url},${spot}" >> ${RESULT_FILE}
        done
    done
done
