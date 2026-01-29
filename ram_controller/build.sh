#!/bin/sh

ISE_DIR="/opt/Xilinx/14.7/ISE_DS/ISE"
ISE_LIB_DIR="/opt/Xilinx/14.7/ISE_DS/ISE/lib/lin64"
ISE_BIN_DIR="/opt/Xilinx/14.7/ISE_DS/ISE/bin/lin64"

XST_PROG="${ISE_BIN_DIR}/xst"
NGDBUILD_PROG="${ISE_BIN_DIR}/ngdbuild"
UNW_NGDBUILD_PROG="${ISE_BIN_DIR}/unwrapped/ngdbuild"
MAP_PROG="${ISE_BIN_DIR}/map"
PAR_PROG="${ISE_BIN_DIR}/par"
TRCE_PROG="${ISE_BIN_DIR}/trce"
BITGEN_PROG="${ISE_BIN_DIR}/bitgen"

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
    mkdir -p xst/projnav.tmp
    ${XST_PROG} -intstyle ise -ifn "/home/themole/TheMole/Projects/github/projects/Papilio/RAMController/main.xst" -ofn "/home/themole/TheMole/Projects/github/projects/Papilio/RAMController/main.syr"
}

#
# Translate
#
translate ()
{
    ${NGDBUILD_PROG} -intstyle ise -dd _ngo -aul -nt timestamp -uc BPC3003-Papilio_One-general.ucf -p xc3s500e-vq100-4 main.ngc main.ngd
    ${UNW_NGDBUILD_PROG} -intstyle ise -dd _ngo -aul -nt timestamp -uc BPC3003-Papilio_One-general.ucf -p xc3s500e-vq100-4 main.ngc main.ngd
}

#
# Map
#
map ()
{
    ${MAP_PROG} -intstyle ise -p xc3s500e-vq100-4 -cm area -ir off -pr off -c 100 -o main_map.ncd main.ngd main.pcf
}

#
# Place & Route
#
place_and_route ()
{
    ${PAR_PROG} -w -intstyle ise -ol high -t 1 main_map.ncd main.ncd main.pcf
}

#
# Generate Post-Place & Route Static Timing
#
post_par ()
{
    ${TRCE_PROG} -intstyle ise -v 3 -s 4 -n 3 -fastpaths -xml main.twx main.ncd -o main.twr main.pcf -ucf BPC3003-Papilio_One-general.ucf
}

#
# Generate Programming File
#
bitgen ()
{
    ${BITGEN_PROG} -intstyle ise -f main.ut main.ncd
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

build ()
{
    wrapper "Synthesize - XST" synthesize
    wrapper "Translate" translate
    wrapper "Map" map
    wrapper "Place & Route" place_and_route
    wrapper "Generate Post-Place & Route Static Timing" post_par
    wrapper "Generate Programming File" bitgen
}


:> build.log
build | tee -a build.log