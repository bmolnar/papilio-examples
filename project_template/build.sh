#!/bin/bash



#
# Command-line options
#
opt_conffile="./project.conf"
opt_logfile="build.log"

usage()
{
    echo "Usage: $0 [-f <conffile>]" 1>&2;
}

#
# Get command line opts/args
#
while getopts "f:o:h" opt; do
    case "${opt}" in
        f)
            opt_conffile="${OPTARG}"
            ;;
	o)
	    opt_logfile="${OPTARG}"
	    ;;
	h)
	    usage
	    exit 0
	    ;;
        *)
            usage
	    exit 1
            ;;
    esac
done
shift $((OPTIND-1))


#
# Load project config file
#
if [ -f "${opt_conffile}" ]; then
    . "${opt_conffile}"
else
    echo "Invalid configuration file ${opt_conffile}" 1>&2
    exit 1
fi


#
# ISE Programs
#
ISE_LIB_DIR="${ISE_DIR}/lib/lin64"
ISE_BIN_DIR="${ISE_DIR}/bin/lin64"

XST_PROG="${ISE_BIN_DIR}/xst"
NGDBUILD_PROG="${ISE_BIN_DIR}/ngdbuild"
MAP_PROG="${ISE_BIN_DIR}/map"
PAR_PROG="${ISE_BIN_DIR}/par"
TRCE_PROG="${ISE_BIN_DIR}/trce"
BITGEN_PROG="${ISE_BIN_DIR}/bitgen"

#
# Project Variables
#
PROJECT_NAME="${PROJECT_FILE%.*}"
BUILDDIR="${PWD}/${PROJECT_NAME}.build"
SRCDIR="${PWD}"

#
# Environment variables needed by subprocesses
#
export LD_LIBRARY_PATH="${ISE_LIB_DIR}"
export XILINX="${ISE_DIR}"




#
# Process wrappers
#

BUILD_LVL="0"

wrap_lines ()
{
    local lvl="${1}"

    IFS=''
    while read line; do
	if [[ "$line" =~ ^\[[0-9]+\].*$ ]]; then
	    printf "%s\n" "${line}"
	else
	    printf "[%s]: %s\n" "${lvl}" "${line}"
	fi;
    done
}

wrap_output ()
{
    local lvl="${1}"

    exec > >(wrap_lines "${lvl}")
    exec 2> >(wrap_lines "${lvl}" >&2)
}

cmdwrap ()
{
    local cmd=${@};
    local rc="0";

    if [ -z "${BUILD_LVL}" ]; then
	BUILD_LVL="0";
    fi
    wrap_output "${BUILD_LVL}"

    (BUILD_LVL=${BUILD_LVL} eval ${cmd})
    rc=$?

    return "${rc}"
}

subproc ()
{
    if [ -z "${BUILD_LVL}" ]; then
	BUILD_LVL="0";
    fi

    (BUILD_LVL=$((${BUILD_LVL} + 1)) cmdwrap ${@})
    return "$?"
}

proc ()
{
    local cmd=${@};
    local rc="0";

    echo "Starting process: cmd=\"${cmd}\""

    subproc ${cmd}

    rc=$?
    if [ "${rc}" -ne "0" ]; then
	echo "Process finished: result=FAILED(${rc})"
    else
	echo "Process finished: result=PASSED"
    fi

    return "${rc}"
}

procgrp ()
{
    #
    # Process group
    #
    echo "Starting process group: processes=[$*]"

    for idx in $*; do
	proc ${idx}

	rc=$?
	if [ "${rc}" -ne "0" ]; then
	    break;
	fi
    done

    if [ "${rc}" -ne "0" ]; then
	echo "Process group finished: result=FAILED(${rc})"
    else
	echo "Process group finished: result=PASSED"
    fi
}


indent_lines ()
{
    local lvl="0";
    local text="";

    IFS=''
    while read line; do
	if [[ "$line" =~ ^\[[0-9]+\]:.*$ ]]; then
	    lvl=$(echo "${line}" | sed -e 's/^\[\([0-9]*\)\]: .*/\1/')
	    text=$(echo "${line}" | sed -e 's/^\[[0-9]*\]: \(.*\)$/\1/')
	else
	    lvl="0"
	    text="${line}"
	fi;

	indent=$((${lvl} * 4))
	spaces=$(printf "%${indent}s" "")

	printf "[%s]: %s%s\n" "${lvl}" "${spaces}" "${text}"
    done
}

setup_output ()
{
    :> ${opt_logfile}
    exec 2>&1 > >(indent_lines | tee -a ${opt_logfile})
}

workflow ()
{
    #setup_output
    (cmdwrap procgrp ${@} 2>&1) | (indent_lines | tee ${opt_logfile})
    #(cmdwrap procgrp ${@} 2>&1) | (tee ${opt_logfile})
}




build_init ()
{
    # Create build directory
    mkdir -p "${BUILDDIR}"
}


#
# Synthesize - XST
#
synthesize ()
{
    local xstfile="${BUILDDIR}/${PROJECT_NAME}.xst"
    local outfile="${BUILDDIR}/${PROJECT_NAME}.syr"


    #
    # Create xstfile
    #
    cat > ${xstfile} <<EOF
        set -tmpdir "xst.tmp"
        set -xsthdpdir "xst"
        run ${XST_OPTS} -p ${PARTNAME} -ifmt mixed -ifn ${SRCDIR}/${PROJECT_FILE} -ofmt NGC -ofn ${BUILDDIR}/${PROJECT_NAME} -top ${TOP_MODULE}
EOF

    #
    # Run 'xst'
    #
    (
        cd ${BUILDDIR} &&

        mkdir -p "xst.tmp" &&

	${XST_PROG} -intstyle ise -ifn "${xstfile}" -ofn "${outfile}" &&
#        ${XST_PROG} -intstyle ise -ofn "${outfile}" <<EOF
#            set -tmpdir "xst.tmp"
#            set -xsthdpdir "xst"
#            run ${XST_OPTS} -p ${PARTNAME} -ifmt mixed -ifn ${SRCDIR}/${PROJECT_FILE} -ofmt NGC -ofn ${BUILDDIR}/${PROJECT_NAME} -top ${TOP_MODULE}
#EOF
        rm -rf "xst.tmp"
    )

}

#
# Translate
#
translate ()
{
    local ngcfile="${BUILDDIR}/${PROJECT_NAME}.ngc"
    local ngdfile="${BUILDDIR}/${PROJECT_NAME}.ngd"
    local ucffile="${SRCDIR}/${UCF_FILE}"

    #
    # Run 'ngdbuild'
    #
    (
        cd "${BUILDDIR}" &&

        ${NGDBUILD_PROG} -intstyle ise -dd ${BUILDDIR}/ngo -aul -nt timestamp -p "${PARTNAME}" \
            -uc "${ucffile}" "${ngcfile}" "${ngdfile}";
    )
}

#
# Map
#
map ()
{
    local infile="${BUILDDIR}/${PROJECT_NAME}.ngd"
    local outfile="${BUILDDIR}/${PROJECT_NAME}_map.ncd"
    local pcffile="${BUILDDIR}/${PROJECT_NAME}.pcf"

    #
    # Run 'map'
    #
    (
	cd "${BUILDDIR}" &&

	${MAP_PROG} -intstyle ise -p "${PARTNAME}" -cm area -ir off -pr off -c 100 \
            -o "${outfile}" "${infile}" "${pcffile}";
    )
}

#
# Place & Route
#
par ()
{
    local infile="${BUILDDIR}/${PROJECT_NAME}_map.ncd"
    local outfile="${BUILDDIR}/${PROJECT_NAME}.ncd"
    local pcffile="${BUILDDIR}/${PROJECT_NAME}.pcf"

    #
    # Run 'par'
    #
    (
        cd "${BUILDDIR}" &&

        ${PAR_PROG} -w -intstyle ise -ol high -t 1 "${infile}" "${outfile}" "${pcffile}";
    )
}

#
# Generate Post-Place & Route Static Timing
#
trace ()
{
    local reportfile="${BUILDDIR}/${PROJECT_NAME}.twr"
    local xreportfile="${BUILDDIR}/${PROJECT_NAME}.twx"
    local infile="${BUILDDIR}/${PROJECT_NAME}.ncd"
    local pcffile="${BUILDDIR}/${PROJECT_NAME}.pcf"
    local ucffile="${SRCDIR}/${UCF_FILE}"

    #
    # Run trace
    #
    (
        cd "${BUILDDIR}" &&

        ${TRCE_PROG} -intstyle ise -v 3 -s 4 -n 3 -fastpaths -ucf "${ucffile}" \
            -xml "${xreportfile}" -o "${reportfile}" "${infile}" "${pcffile}";
    )
}

#
# Generate Programming File
#
bitgen ()
{
    local infile="${BUILDDIR}/${PROJECT_NAME}.ncd"
    local bitfile="${BUILDDIR}/${PROJECT_NAME}.bit"

    #
    # Run trace
    #
    (
        cd "${BUILDDIR}" &&

        ${BITGEN_PROG} -intstyle ise ${BITGEN_OPTS} "${infile}" "${bitfile}";
    )
}

#
# Clean build products
#
clean ()
{
    rm -rf ${BUILDDIR}
}







#
# Perform entire build workflow
#
build ()
{
    procgrp build_init synthesize translate map par trace bitgen
}






case $1 in
    build)
        workflow build
        ;;
    clean)
        workflow clean
        ;;
    synthesize)
	workflow synthesize
	;;
    translate)
	workflow translate
	;;
    map)
	workflow map
	;;
    par)
	workflow par
	;;
    trace)
	workflow trace
	;;
    bitgen)
	workflow bitgen
	;;
    "")
        workflow build
        ;;
    *)
        ;;
esac

wait
