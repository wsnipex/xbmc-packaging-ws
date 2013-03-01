#!/bin/bash

if [[ $1 == "-h" ]] || [[ $1 == "--help" ]] || [[ -z $1 ]]
then
	echo "usage $(basename $0) distribution"
	exit 1
else
	dist=$1
	echo "preparing build for $dist"
fi

[[ $(basename $PWD) == "debian" ]] || cd debian

###
# add a tag to the package versions, needed for rebuilds without upstream version changes
###
[[ -f versiontag ]] && tag=$(cat versiontag) || tag="0"

###
# detect Pvr Api version
###
PVRAPI=$(awk '/XBMC_PVR_API_VERSION/ {gsub("\"",""); print $3 }' ../xbmc/xbmc_pvr_types.h)
echo "detected Xbmc PVR-API: $PVRAPI"

###
# Create control and changelog. This file MUST exist with the correct package name before calling debuild
###
echo "Generating changelog with PVR Api version $PVRAPI"
sed -e "s/#APIVERSION#/$PVRAPI/g" -e "s/#DIST#/$dist/g" changelog.in > changelog
echo "Generating control file"
sed "s/#APIVERSION#/$PVRAPI/g" control.in > control

###
# Define upstream addon name to package name mapping
###
declare -A PACKAGES=(
	["pvr.hts"]="xbmc-pvr-tvheadend-hts${PVRAPI}"
	["pvr.vuplus"]="xbmc-pvr-vuplus${PVRAPI}"
	["pvr.mediaportal.tvserver"]="xbmc-pvr-mediaportal-tvserver${PVRAPI}"
	["pvr.dvbviewer"]="xbmc-pvr-dvbviewer${PVRAPI}"
	["pvr.argustv"]="xbmc-pvr-argustv${PVRAPI}"
	["pvr.mythtv.cmyth"]="xbmc-pvr-mythtv-cmyth${PVRAPI}"
	["pvr.vdr.vnsi"]="xbmc-pvr-vdr-vnsi${PVRAPI}"
	["pvr.nextpvr"]="xbmc-pvr-nextpvr${PVRAPI}"
	["pvr.demo"]="xbmc-pvr-demo${PVRAPI}"
	["pvr.njoy"]="xbmc-pvr-njoy${PVRAPI}"
)

###
# loop over all packages and create the specific changelog and version files used by debuild
###
for package in "${!PACKAGES[@]}"
do
	echo "creating changelog for: $package"
	changelog="../addons/$package/addon/changelog.txt"
	addonxml="../addons/$package/addon/addon.xml.in"
	aversion=$(awk -F'=' '!/<?xml/ && /version/ && !/>/ {gsub("\"",""); print $2}' $addonxml)
	pvrapiversion=$(awk -F'=' '/import addon="xbmc.pvr"/ {gsub("\"",""); gsub("/>",""); print $3}' $addonxml)

	[[ -f ${PACKAGES["$package"]}.changelog ]] && mv ${PACKAGES["$package"]}.changelog ${PACKAGES["$package"]}.changelog.old

	version="${aversion}-${tag}${dist}"
	echo "${version}" > ${PACKAGES["$package"]}.version
	if [[ -f $changelog ]]
	then
		dch -c ${PACKAGES["$package"]}.changelog --create --empty --package xbmc-pvr-addons${PVRAPI} -v "${version}" --distribution ${dist} --force-distribution 2>/dev/null $(cat $changelog | tail -80)
	else
		dch -c ${PACKAGES["$package"]}.changelog --create --empty --package xbmc-pvr-addons${PVRAPI} -v "${version}" --distribution ${dist} --force-distribution 2>/dev/null "no upstream changelog available"
	fi
done

###
# special handling for vdr-plugin-vnsiserver
###
echo "creating changelog for: vdr-plugin-vnsiserver"
package="vdr-plugin-vnsiserver${PVRAPI}"
version="1:"$(awk -F'=' '/\*VERSION/ {gsub("\"",""); gsub(" ",""); gsub(";",""); print $2}' ../addons/pvr.vdr.vnsi/vdr-plugin-vnsiserver/vnsi.h)"-${tag}${dist}"
echo "${version}" > ${package}.version

[[ -f "${package}.changelog" ]] && mv ${package}.changelog ${package}.changelog.old
dch -c ${package}.changelog --create --empty --package xbmc-pvr-addons${PVRAPI} -v"${version}" --distribution ${dist} --force-distribution 2>/dev/null "no upstream changelog available"

exit 0
