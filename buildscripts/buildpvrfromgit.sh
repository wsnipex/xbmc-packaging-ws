#!/bin/bash

. /home/pi/.bashrc

########## Example config ##########

## put in a config file ##
#TAG="beta1"
#TAGFILE="$TAG.rev"
#TAGREV=$(cat $TAGFILE)

#PPA="ppa:wsnipex/xbmc-nightly"

#REPO_DIR="/data/packages/xbmc-pvr-addons/git-pvr-addons"
#OUTPUT_DIR="/data/packages/xbmc-pvr-addons/output"
#BUILD_REPO="frodo"
#UPSTREAM_REPO="origin"
#UPSTREAM_BRANCH="frodo"
#PVRADDONS_REPO_DIR="/data/packages/xbmc-mainline/xbmc-pvr-addons"
#PVR_REPO="pvr-addons-upstream"
#PVR_BRANCH="master"
#DEBIAN="/data/packages/xbmc-pvr-addons/debian"
#LOG="$PWD/gitbuild.log"
#FORCE_BUILD="True"
#DISTS="quantal precise oneiric"
##DISTS="quantal"
########################################

function updateRepo {
    cd $REPO_DIR || exit 1
    git checkout $BUILD_REPO >/dev/null 2>&1 || exit 2
    git fetch $UPSTREAM_REPO >/dev/null 2>&1 || exit 2
    createChangelog
    git reset --hard $UPSTREAM_REPO/$UPSTREAM_BRANCH >> $LOG || exit 2
    git clean -Xfd
}

function getGitRev {
    local branch=$1
    cd $REPO_DIR || exit 1
    #REV=$(git log --no-merges -1 --pretty=format:"%h %an %B" $branch)
    #REV=$(git log --no-merges -1 --pretty=format:"%h" $branch)
    REV=$(git log -1 --pretty=format:"%h" $branch)
    echo $REV # return
}

function compareRevs {
    local currev=$1
    local upstreamrev=$2
    [[ $currev != $upstreamrev ]] && echo "False" || echo "True"
}

function buildPackage {
    # check if build repo updated ok
    local newrev=$(getGitRev $BUILD_REPO)
    if [[ $(compareRevs $newrev $UPSTREAMREV) == "False" ]]
    then
        echo "local repo update error" >> $LOG
        exit 2
    fi
    echo "building new package with git rev $UPSTREAMREV" >> $LOG
    [[ -z $TAG ]] && TAG=$UPSTREAMREV
    [[ -z $TAGREV ]] && TAGREV=0
    archiveRepo
    cd $REPO_DIR/debian
    #sed -i "s/git.*-0/${DEST#xbmc-pvr-addons${PVRAPI}-*~}-${TAGREV}/g" changelog.in
    sed -i "s/#PACKAGEVERSION#/${DEST#xbmc-pvr-addons${PVRAPI}-}/g" changelog.in
    [[ $(createDebs) -eq 0 ]] && uploadpkgs #&& saveTagRev
}

function archiveRepo {
    cd $REPO_DIR || exit 1
    if [[ -f xbmc/xbmc_pvr_types.h ]] 
    then
        PVRAPI=$(awk '/XBMC_PVR_API_VERSION/ {gsub("\"",""); print $3 }' xbmc/xbmc_pvr_types.h)
        echo "detected PVR API: ${PVRAPI}"
    else
        echo "could not determine PVR API version" >> $LOG 2>&1 
        exit 4
    fi
    [[ -d debian ]] && rm -rf debian
    DEST="xbmc-pvr-addons${PVRAPI}-1.0.0~git$(date '+%Y%m%d.%H%M')-${TAG}"
    cp -r $DEBIAN . #TODO better debian dir handling
    mv $(basename $DEBIAN) debian 2>/dev/null
    echo $TAGREV > debian/versiontag
    #git archive --format tar.gz -o ../${DEST}.tar.gz $BUILD_REPO >> $LOG 2>&1
    cd ..
    tar -czf ${DEST}.tar.gz -h --exclude .git $(basename $REPO_DIR)
    ln -s ${DEST}.tar.gz ${DEST/-1/_1}.orig.tar.gz
    echo "Output Archive: ${DEST}.tar.gz" >> $LOG
}

function updatePvrAddons {
    cd $PVRADDONS_REPO_DIR || exit 1
    echo "updating PVR Addons in $PVRADDONS_REPO_DIR" >> $LOG
    echo $PWD
    git clean -Xfd #>> $LOG
    git fetch $PVR_REPO >> $LOG 2>&1
    git reset --hard $PVR_REPO/$PVR_BRANCH >> $LOG 2>&1
    cd ..
    mkdir $REPO_DIR/pvr-addons
    cp -r $PVRADDONS_REPO_DIR/* $REPO_DIR/pvr-addons
}

function createDebs {
    cd $REPO_DIR || exit 1
    for i in $DISTS
    do
        echo "building $i" >> $LOG
        debian/prepare-build.sh $i >> $LOG
        #sed "s/dist/$i/g" debian/changelog.tmp > debian/changelog
	#sed -i "s/0dist/${TAGREV}${i}/g" debian/*.changelog 2>/dev/null
        debuild $BUILDOPT -S -k"wsnipex <wsnipex@a1.net>" >> $LOG 2>&1
        #BUILDOPT="-sd"
    done
    echo $?
}

function uploadpkgs {
    cd $REPO_DIR/..
    PKGS=$(ls ${DEST/-1/_1}*.changes)
    for pkg in ${PKGS[*]}
    do
        echo "uploading $pkg to $PPA" >> $LOG 2>&1
        dput $PPA $pkg >> $LOG
    done
    [ $? -eq 0 ] && mv ${DEST/-1/_1}* ${DEST}* $OUTPUT_DIR
}

function saveTagRev {
    echo "$TAGREV" > $TAGFILE
}

function createChangelog {
    #cd $REPO_DIR || exit 1
    local changes="/tmp/changes-tmp"
    local commits="/tmp/commits-tmp"
    local author
    local subject

    rm -f $changes $commits >/dev/null 2>&1
    git log --no-merges --pretty=format:"%an|%s"%n $UPSTREAM_REPO/$UPSTREAM_BRANCH --not $BUILD_REPO > $commits
    cat $commits | sed '/^$/d' | while read line
    do
    #echo $line
       echo >> $changes
       author=$(echo $line | awk -F '|' '{ print $1}')
       subject=$(echo $line | awk -F '|' '{ print $2}')
       echo '  ['$author']' >> $changes
       echo '   * '$subject >> $changes
    done
    echo >> $changes
    cp $DEBIAN/changelog.in $DEBIAN/changelog.in.old
    sed -i "/^xbmc/r $changes" $DEBIAN/changelog.in
}


###
# Main
###
    # Load config file
    if ! [ -f $1 ]
    then
        echo "config file not found"
        echo "usage $0 configfile"
        exit 3
    else
        . $1
        echo "#--------------------------#" >> $LOG
        echo "using config file $1 with contents:" >> $LOG
        cat $1 >> $LOG
    fi

    date >> $LOG
    CURREV=$(getGitRev $BUILD_REPO)
    updateRepo
    UPSTREAMREV=$(getGitRev $UPSTREAM_REPO/$UPSTREAM_BRANCH)
    echo "CURREV: $CURREV" >> $LOG
    echo "UPSTREAMREV: $UPSTREAMREV" >> $LOG

    if [[ $(compareRevs $CURREV $UPSTREAMREV) == "False" ]] || [[ $FORCE_BUILD == "True" ]]
    then    
        buildPackage
    else
        echo "already at latest revision" >> $LOG
        exit 0
    fi

