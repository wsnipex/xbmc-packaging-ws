Description: adds a xbmc debug info collection script
 adds a xbmc debug info collection script. Collects important settings,
 logs from xbmc and the running OS
Author: wsnipex <wsnipex@a1.net>

--- /dev/null
+++ xbmc-12.0~git20120709.1113-c6fc742/collectsysteminfo.sh
@@ -0,0 +1,133 @@
+#!/bin/bash
+# 
+# Xbmc Xvba debug info collector script
+# author: wsnipex
+# 
+# License: GPLv2
+#
+ME=$(basename $0)
+log="/tmp/$ME.log"
+ANON="<user>|<pass>|username|password|user=|pass="
+SEP="#-----------------------------------------------------------------------------#"
+
+if [[ $(uname -a) =~ Ubuntu ]] 
+then
+    OS="ubuntu"
+    PKGMGR="dpkg -l"
+    APT=true
+
+elif [[ $(uname -a) =~ debian ]] 
+then
+    OS="debian"
+    PKGMGR="dpkg -l"
+    APT=true
+
+elif [[ $(uname -a) =~ suse ]]
+then
+    OS="suse"
+    PKGMGR="rpm -qa"
+    APT=false
+
+fi
+
+### System Info ###
+echo "System Type:" > $log
+uname -a  >> $log
+echo "#" >> $log
+
+echo "User Info:" >> $log
+id >> $log
+echo "#" >> $log
+
+echo "Renice enabled:" >> $log
+grep -E "$USER.*nice" /etc/security/limits.conf >> $log || echo "not found" >> $log
+echo $SEP >> $log
+
+### Driver Info ###
+echo "GFX Driver:" >> $log
+FGLRX=$(which fglrxinfo) 
+if [[ -f $FGLRX ]] 
+then
+    echo "..found AMD fglrx" >> $log
+    $FGLRX >> $log
+    echo "#" >> $log
+    $PKGMGR | grep fglrx >> $log 
+    echo "#" >> $log
+    echo "# checking h264 L5.1 support:" >> $log
+    grep "HWUVD_H264Level51" /etc/ati/amdpcsdb >> $log 2>&1
+    echo "# checking V-SYNC" >> $log
+    grep -i "Sync" /etc/ati/amdpcsdb >> $log 2>&1
+    echo "# checking TearFree" >> $log
+    grep -i "Tear" /etc/ati/amdpcsdb >> $log 2>&1
+    echo "#" >> $log
+fi
+
+NV=$(which nvidia-settings)
+if [[ -f $NV ]] 
+then
+    echo "..found Nvidia" >> $log
+    $NV >> $log
+fi
+echo $SEP >> $log
+
+### Xbmc Info ###
+echo "XBMC version:" >> $log
+xbmc --version 2>&1 >> $log
+echo "#" >> $log
+echo "XBMC package:" >> $log
+$PKGMGR | grep xbmc >> $log
+echo "#" >> $log
+[[ $APT ]] && apt-cache policy xbmc >> $log
+echo "#" >> $log
+echo "Advancedsettings:" >> $log
+[[ -f ~/.xbmc/userdata/advancedsettings.xml ]] && cat ~/.xbmc/userdata/advancedsettings.xml | grep -Ev $ANON >> $log || echo "not found" >> $log
+echo "#" >> $log
+echo "Keyboard.xml:" >> $log
+[[ -f ~/.xbmc/userdata/keymaps/keyboard.xml ]] && cat ~/.xbmc/userdata/keymaps/keyboard.xml >> $log || echo "not found" >> $log
+echo "#" >> $log
+echo "Xbmc Video Settings:" >> $log
+sed -n '/videoplayer/,/\/videoplayer/p' ~/.xbmc/userdata/guisettings.xml >> $log
+sed -n '/videoscreen/,/\/videoscreen/p' ~/.xbmc/userdata/guisettings.xml >> $log
+echo $SEP >> $log
+
+### Sound Info ###
+echo "Sound Info" >> $log
+echo "Xbmc audio settings:" >> $log
+sed -n '/audiooutput/,/\/audiooutput/p' ~/.xbmc/userdata/guisettings.xml >> $log
+echo "#" >> $log
+echo "/etc/asound.conf:" >> $log
+[[ -f /etc/asound.conf ]] && cat /etc/asound.conf >> $log || echo "not found" >> $log
+echo "#" >> $log
+echo "~/.asoundrc:" >> $log
+[[ -f ~/.asoundrc ]] && cat ~/.asoundrc >> $log || echo "not found" >> $log
+echo "#" >> $log
+echo "Alsa:" >> $log
+echo "aplay -l:" >> $log
+aplay -l >> $log
+echo "#" >> $log
+echo "aplay -L:" >> $log
+aplay -L >> $log
+echo "#" >> $log
+echo "amixer:" >> $log
+amixer >> $log
+echo $SEP >> $log
+
+
+### XBMC log ###
+echo $SEP >> $log
+echo "" >> $log
+cat ~/.xbmc/temp/xbmc.log | grep -Ev $ANON >> $log
+
+PASTEBIN=$(which pastebinit)
+if [[ $PASTEBIN ]] 
+then
+    #$PASTEBIN $log
+    echo "" >> $log
+    echo "good, pastebinit is installed"
+    echo "do you want to upload the collected information in $log to pastebin? [y/N]"
+    read upload
+    [[ "$upload" == "y" ]] || [[ "$upload" == "Y" ]] && $PASTEBIN $log
+else
+    echo "pastebinit not found...please post $log manually or install pastebinit and rerun me"
+fi
+#cat $log
