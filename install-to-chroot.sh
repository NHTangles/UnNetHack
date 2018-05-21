#!/bin/bash
# 
# Ideas and some parts from the original dgl-create-chroot (by joshk@triplehelix.org, modifications by jilles@stack.nl)
# More by <paxed@alt.org>
# More by Michael Andrew Streib <dtype@dtype.org>
#
# Adapted for install of unnethack in NAO-Style chroot by Tangles
#
# Licensed under the MIT License
# https://opensource.org/licenses/MIT

# autonamed chroot directory. Can rename.
DATESTAMP=`date +%Y%m%d-%H%M%S`
NAO_CHROOT="/opt/nethack/hardfought.org"
# config outside of chroot
DGL_CONFIG="/opt/nethack/dgamelaunch.conf"
# already compiled versions of dgl and nethack
DGL_GIT="/home/build/dgamelaunch"
NETHACK_GIT="/home/build/UnNetHack"
# the user & group from dgamelaunch config file.
USRGRP="games:games"
# COMPRESS from include/config.h; the compression binary to copy. leave blank to skip.
COMPRESSBIN="/bin/gzip"
# fixed data to copy (leave blank to skip)
NH_GIT="/home/build/UnNetHack"
NH_BRANCH="5.3.1"
# HACKDIR from include/config.h; aka nethack subdir inside chroot
NHSUBDIR="un531"
# VAR_PLAYGROUND from include/unixconf.h
NH_VAR_PLAYGROUND="/un531/var/unnethack"
# nhdat location
NHDAT_DIR="/un531/share/unnethack"
# only define this if dgl was configured with --enable-sqlite
SQLITE_DBFILE="/dgldir/dgamelaunch.db"
# END OF CONFIG
##############################################################################

errorexit()
{
    echo "Error: $@" >&2
    exit 1
}

findlibs()
{
  for i in "$@"; do
      if [ -z "`ldd "$i" | grep 'not a dynamic executable'`" ]; then
         echo $(ldd "$i" | awk '{ print $3 }' | egrep -v ^'\(' | grep lib)
         echo $(ldd "$i" | grep 'ld-linux' | awk '{ print $1 }')
      fi
  done
}

set -e

umask 022

echo "Creating inprogress and userdata directories"
mkdir -p "$NAO_CHROOT/dgldir/inprogress-un531"
chown "$USRGRP" "$NAO_CHROOT/dgldir/inprogress-un531"
mkdir -p "$NAO_CHROOT/dgldir/extrainfo-un531"
chown "$USRGRP" "$NAO_CHROOT/dgldir/extrainfo-un531"

echo "Making $NAO_CHROOT/$NHSUBDIR"
mkdir -p "$NAO_CHROOT/$NHSUBDIR"

echo "Creating NetHack variable dir stuff."
mkdir -p "$NAO_CHROOT$NH_VAR_PLAYGROUND"
mkdir -p "$NAO_CHROOT$NH_VAR_PLAYGROUND/saves"
mkdir -p "$NAO_CHROOT$NH_VAR_PLAYGROUND/level"
mkdir -p "$NAO_CHROOT$NH_VAR_PLAYGROUND/bones"
mkdir -p "$NAO_CHROOT$NH_VAR_PLAYGROUND/whereis"
touch "$NAO_CHROOT$NH_VAR_PLAYGROUND/logfile"
touch "$NAO_CHROOT$NH_VAR_PLAYGROUND/perm"
touch "$NAO_CHROOT$NH_VAR_PLAYGROUND/record"
touch "$NAO_CHROOT$NH_VAR_PLAYGROUND/xlogfile"
touch "$NAO_CHROOT$NH_VAR_PLAYGROUND/livelog"

# everything created so far needs the chown.
( cd $NAO_CHROOT/$NHSUBDIR ; chown -R "$USRGRP" * )

# Everything below here should remain owned by root.
echo "Copying NetHack nhdat"
mkdir -p "$NAO_CHROOT$NHDAT_DIR"
cp "$NETHACK_GIT/dat/nhdat" "$NAO_CHROOT$NHDAT_DIR"
chmod 644 "$NAO_CHROOT$NHDAT_DIR/nhdat"

NETHACKBIN="$NETHACK_GIT/src/unnethack"
if [ -n "$NETHACKBIN" -a ! -e "$NETHACKBIN" ]; then
  errorexit "Cannot find unnethack binary $NETHACKBIN"
fi

if [ -n "$NETHACKBIN" -a -e "$NETHACKBIN" ]; then
  echo "Copying $NETHACKBIN"
  cd "$NAO_CHROOT/$NHSUBDIR"
  NHBINFILE="`basename $NETHACKBIN`-$DATESTAMP"
  cp "$NETHACKBIN" "$NHBINFILE"
  rm -f unnethack
  ln -s "$NHBINFILE" unnethack
  LIBS="$LIBS `findlibs $NETHACKBIN`"
  cd "$NAO_CHROOT"
fi

RECOVER="$NETHACK_GIT/util/recover"

if [ -n "$RECOVER" -a -e "$RECOVER" ]; then
  echo "Copying $RECOVER"
  cp "$RECOVER" "$NAO_CHROOT/$NHSUBDIR/var/unnethack"
  LIBS="$LIBS `findlibs $RECOVER`"
  cd "$NAO_CHROOT"
fi


LIBS=`for lib in $LIBS; do echo $lib; done | sort | uniq`
echo "Copying libraries:" $LIBS
for lib in $LIBS; do
  mkdir -p "$NAO_CHROOT`dirname $lib`"
  if [ -f "$NAO_CHROOT$lib" ]
  then
    echo "$NAO_CHROOT$lib already exists - skipping."
  else
    cp $lib "$NAO_CHROOT$lib"
  fi
done

echo "Finished."
