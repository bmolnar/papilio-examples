#!/bin/sh

ISE_DIR="/opt/Xilinx/14.7/ISE_DS/ISE"
ISE_LIB_DIR="/opt/Xilinx/14.7/ISE_DS/ISE/lib/lin64"
ISE_BIN_DIR="/opt/Xilinx/14.7/ISE_DS/ISE/bin/lin64"

XST_PROG="${ISE_BIN_DIR}/xst"
NGDBUILD_PROG="${ISE_BIN_DIR}/ngdbuild"
MAP_PROG="${ISE_BIN_DIR}/map"
PAR_PROG="${ISE_BIN_DIR}/par"
TRCE_PROG="${ISE_BIN_DIR}/trce"
BITGEN_PROG="${ISE_BIN_DIR}/bitgen"

TOP_LEVEL_XST="top_level.xst"
TOP_LEVEL_BASE="${TOP_LEVEL_XST%.*}"
PARTNAME="xc3s500e-vq100-4"
CONSTRAINT_UCF="top_level_papilio_one.ucf"


#
# Environment variables needed by subprocesses
#
export LD_LIBRARY_PATH="${ISE_LIB_DIR}"
export XILINX="${ISE_DIR}"



#
# Synthesize - XST
#
synthesize ()
{
    #
    # Create tmpdir if set in xst file
    #
    local tmpdir=`cat "${TOP_LEVEL_BASE}.xst" | grep -- "set[ ]*-tmpdir" | sed -e "s/set[ ]*-tmpdir[ ]*//" | sed -e 's/"//g'`
    if [ -n "${tmpdir}" ]; then
	mkdir -p "${tmpdir}"
    fi

    ${XST_PROG} -intstyle ise -ifn "${TOP_LEVEL_BASE}.xst" -ofn "${TOP_LEVEL_BASE}.syr"
}

#
# Translate
#
translate ()
{
    ${NGDBUILD_PROG} -intstyle ise -dd _ngo -aul -nt timestamp -uc "${CONSTRAINT_UCF}" -p "${PARTNAME}" \
        "${TOP_LEVEL_BASE}.ngc" "${TOP_LEVEL_BASE}.ngd"
}

#
# Map
#
map ()
{
    ${MAP_PROG} -intstyle ise -p "${PARTNAME}" -cm area -ir off -pr off -c 100 -o "${TOP_LEVEL_BASE}_map.ncd" \
        "${TOP_LEVEL_BASE}.ngd" "${TOP_LEVEL_BASE}.pcf"
}

#
# Place & Route
#
place_and_route ()
{
    ${PAR_PROG} -w -intstyle ise -ol high -t 1 "${TOP_LEVEL_BASE}_map.ncd" "${TOP_LEVEL_BASE}.ncd" "${TOP_LEVEL_BASE}.pcf"
}

#
# Generate Post-Place & Route Static Timing
#
post_par ()
{
    ${TRCE_PROG} -intstyle ise -v 3 -s 4 -n 3 -fastpaths -xml "${TOP_LEVEL_BASE}.twx" \
        "${TOP_LEVEL_BASE}.ncd" -o "${TOP_LEVEL_BASE}.twr" "${TOP_LEVEL_BASE}.pcf" -ucf "${CONSTRAINT_UCF}"
}

#
# Generate Programming File
#
bitgen ()
{
    ${BITGEN_PROG} -intstyle ise -f "${TOP_LEVEL_BASE}.ut" "${TOP_LEVEL_BASE}.ncd"
}





wrapper ()
{
    local proc="${1}"; shift

    echo "Started : \"${proc}\""

    (eval $@)

    local rc=$?
    if [ "${rc}" -ne "0" ]; then
        echo "Process \"${proc}\" failed"
        exit "${rc}"
    else
        echo "Process \"${proc}\" completed successfully"
    fi
}

build_wrap ()
{
    wrapper "Synthesize - XST" synthesize
    wrapper "Translate" translate
    wrapper "Map" map
    wrapper "Place & Route" place_and_route
    wrapper "Generate Post-Place & Route Static Timing" post_par
    wrapper "Generate Programming File" bitgen
}

build ()
{
    :> build.log
    build_wrap | tee -a build.log
}

clean ()
{
    rm -f ${TOP_LEVEL_BASE}.bgn
    rm -f ${TOP_LEVEL_BASE}.bit
    rm -f ${TOP_LEVEL_BASE}_bitgen.xwbt
    rm -f ${TOP_LEVEL_BASE}.bld
    rm -f ${TOP_LEVEL_BASE}.drc
    rm -f ${TOP_LEVEL_BASE}.lso
    rm -f ${TOP_LEVEL_BASE}_map.map
    rm -f ${TOP_LEVEL_BASE}_map.mrp
    rm -f ${TOP_LEVEL_BASE}_map.ncd
    rm -f ${TOP_LEVEL_BASE}_map.ngm
    rm -f ${TOP_LEVEL_BASE}_map.xrpt
    rm -f ${TOP_LEVEL_BASE}.ncd
    rm -f ${TOP_LEVEL_BASE}.ngc
    rm -f ${TOP_LEVEL_BASE}.ngd
    rm -f ${TOP_LEVEL_BASE}_ngdbuild.xrpt
    rm -f ${TOP_LEVEL_BASE}.ngr
    rm -f ${TOP_LEVEL_BASE}.pad
    rm -f ${TOP_LEVEL_BASE}_pad.csv
    rm -f ${TOP_LEVEL_BASE}_pad.txt
    rm -f ${TOP_LEVEL_BASE}.par
    rm -f ${TOP_LEVEL_BASE}_par.xrpt
    rm -f ${TOP_LEVEL_BASE}.pcf
    rm -f ${TOP_LEVEL_BASE}.ptwx
    rm -f ${TOP_LEVEL_BASE}_summary.xml
    rm -f ${TOP_LEVEL_BASE}.syr
    rm -f ${TOP_LEVEL_BASE}.twr
    rm -f ${TOP_LEVEL_BASE}.twx
    rm -f ${TOP_LEVEL_BASE}.unroutes
    rm -f ${TOP_LEVEL_BASE}_usage.xml
    rm -f ${TOP_LEVEL_BASE}.xpi
    rm -f ${TOP_LEVEL_BASE}_xst.xrpt
    rm -f usage_statistics_webtalk.html
    rm -f webtalk.log
    rm -rf _ngo
    rm -rf xlnx_auto_0_xdb
    rm -rf _xmsgs
    rm -rf xst
}



case $1 in
    build)
        build
        ;;
    clean)
        clean
        ;;
    "")
        build
        ;;
    *)
        ;;
esac
