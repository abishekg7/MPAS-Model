#!/bin/sh

nml_replace(){
    PARAM=$1
    VALUE=$2
    FILE=$3
    if grep -q '^[[:space:]]*'${PARAM}'[[:space:]]*=' ${FILE}; then
        sed 's/\(^\s*'$PARAM'\s*=\s*\).*$/\1'${VALUE}'/' < ${FILE} > ${FILE}.out
        mv ${FILE}.out ${FILE}
    else
        echo "$0:${FUNCNAME}: ERROR parameter ${PARAM} not found in ${FILE}"
        exit 1
    fi
}

nml_replace_quotes(){
    PARAM=$1
    VALUE="'$2'"
    FILE=$3
    if grep -q '^[[:space:]]*'${PARAM}'[[:space:]]*=' ${FILE}; then
        sed 's/\(^\s*'$PARAM'\s*=\s*\).*$/\1'${VALUE}'/' < ${FILE} > ${FILE}.out
        mv ${FILE}.out ${FILE}
    else
        echo "$0:${FUNCNAME}: ERROR parameter ${PARAM} not found in ${FILE}"
        exit 1
    fi
}

stream_replace(){
    FILETYPE=$1
    PARAM=$2
    VALUE=$3
    FILE=$4
    if grep -q '<[A-Za-z_]*stream name="'${FILETYPE}'"' ${FILE}; then
        sed '/<.*stream name="'$FILETYPE'"/,/\/>/s/\('$PARAM'="\)[^"]*\(".*\)/\1'$VALUE'\2/' < ${FILE} > ${FILE}.out
        mv ${FILE}.out ${FILE}
    else
        echo "$0:${FUNCNAME}: ERROR parameter ${FILETYPE} not found in ${FILE}"
        exit 1
    fi
}

function extract_totaltime(){
    log_file_path=$1

    eval "totaltime=\$( sed -n '/timer_name/,/-------/p'  $log_file_path | awk '{print \$4}' | head -2 | tail -1 )"
}


function diff_output
{
    
    FILE_TEST=$1
    FILE_REF=$2

    module load cdo
    which cdo
    
    # status variable that is evaluated after the function call
    STATUS=0
    
    if [ -f "$FILE_TEST" ] && [ -f "$FILE_REF" ]; then
        echo "Comparing $FILE_TEST and $FILE_REF"
        cdo diffv ${FILE_TEST} ${FILE_REF} #> ${DIFF_FILE}
        STATUS=$?
        if [ $STATUS == 0 ]; then
                banner 42 "The experiments are bit-identical"
                return 0
        else
                banner 42 "The experiments are NOT bit-identical"
                return 1
        fi
    else
        echo "File(s) for $TYPE not found:"
        if ! [ -f  "$FILE_TEST" ]; then echo "FILE_TEST does not exist: $FILE_TEST"; fi
        if ! [ -f  "$FILE_REF" ]; then echo "FILE_REF does not exist: $FILE_REF"; fi
        return 1
    fi
}

