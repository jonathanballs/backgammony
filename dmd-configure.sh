#!/bin/sh

cat <<EOF >Makefile
all:
	make -f posix.mak -j8 AUTO_BOOTSTRAP=1

install:
	mkdir -p /app/bin
	cp generated/linux/release/64/dmd /app/bin
	echo -e "[Environment64]" > /app/bin/dmd.conf
	echo -e "DFLAGS=-I/app/src/phobos -I/app/src/druntime/import -L-L/app/linux/release/64" >> /app/bin/dmd.conf

EOF
