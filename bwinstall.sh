#!/usr/bin/env sh

# bwinstall.sh
# Copyright 2020 Christian Baer
# http://git.debilux.org/chbaer/bwinstall

# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:

# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTI

# Initialize defaults
DATA_DIR="/var/db/bitwarden"
LOG_FILE="/var/log/bitwarden.log"

BASEDIR="/usr/local/share/bitwarden"
RC_SCRIPT="/usr/local/etc/rc.d/bitwarden"
RC_CONF_D_SCRIPT="/etc/rc.conf.d/bitwarden"

## Check if bitwarden_rs is installed and set UPDATE flag if it is
if [ -f "${BASEDIR}/bin/bitwarden_rs" ]; then
	UPDATE="true"
fi

## Download rustup and run it
echo ">>> Getting latest version of rustup."
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

## Download latest verison of bitwarden_rs
echo ">>> Downloading latest version of bitwarden_rs."
if [ -z "$UPDATE" ]; then
	## Generate ADMIN_TOKEN
	ADMIN_TOKEN=$(openssl rand -base64 16)
	mkdir -p ${BASEDIR}/src
	git clone https://github.com/dani-garcia/bitwarden_rs/ ${BASEDIR}/src
else
	service bitwarden stop
	git -C ${BASEDIR}/src fetch
fi

## Build and install bitwarden_rs
echo ">>> Building bitwarden_rs."
TAG=$(git -C ${BASEDIR}/src tag --sort=v:refname | tail -n1)
git -C ${BASEDIR}/src checkout ${TAG}
cd ${BASEDIR}/src && $HOME/.cargo/bin/cargo build --features sqlite --release

echo ">>> Install bitwarden_rs."
cd ${BASEDIR}/src && $HOME/.cargo/bin/cargo install diesel_cli --no-default-features --features sqlite-bundled
cp -r ${BASEDIR}/src/target/release ${BASEDIR}/bin

## Download prebuilt version of webvault and install it
echo ">>> Downloading and installing latest version of bitwarden webvault."
WEB_RELEASE_URL=$(curl -Ls -o /dev/null -w "%{url_effective}" https://github.com/dani-garcia/bw_web_builds/releases/latest)
WEB_TAG="${WEB_RELEASE_URL##*/}"

fetch http://github.com/dani-garcia/bw_web_builds/releases/download/$WEB_TAG/bw_web_$WEB_TAG.tar.gz -o ${BASEDIR}
tar -xzvf ${BASEDIR}/bw_web_$WEB_TAG.tar.gz -C ${BASEDIR}/
rm ${BASEDIR}/bw_web_"$WEB_TAG".tar.gz

if [ -z "$UPDATE" ]; then
	## Create user and directories
	pw user add bitwarden -c bitwarden -u 725 -d /nonexistent -s /usr/bin/nologin
	mkdir -p ${DATA_DIR} /usr/local/etc/rc.d /usr/local/etc/rc.conf.d

	## Install rc script
	echo ">>> Installing rc script ${RC_SCRIPT}."
	cat <<-\EOF >>${RC_SCRIPT}
	#!/bin/sh

	# PROVIDE: bitwarden
	# REQUIRE: LOGIN DAEMON NETWORKING FILESYSTEMS
	# KEYWORD: jail rust

	. /etc/rc.subr

	name="bitwarden"

	rcvar=\${name}_enable
	pidfile="/var/run/\${name}.pid"
	command="/usr/sbin/daemon"
	command_args="-u bitwarden -c -f -P \${pidfile} -r ${BASEDIR}/bin/bitwarden_rs"
	load_rc_config \$name
	run_rc_command "\$1"
	EOF

	chmod u+x ${RC_SCRIPT}

	## Install rc.conf.d script
	echo ">>> Installing rc.conf.d script ${RC_CONF_D_SCRIPT}."

	cat <<-\EOF >>${RC_CONF_D_SCRIPT}
	## This is the config file for bitwarden_rs.
	## Check https://github.com/dani-garcia/bitwarden_rs/blob/master/.env.template for a list of the possible settings.

	export DATA_FOLDER="${DATA_DIR}"
	export LOG_FILE="${LOG_FILE}"
	export WEB_VAULT_FOLDER="${BASEDIR}/web-vault"
	export LOG_LEVEL="trace"
	export WEBSOCKET_ENABLED="true"
	export ROCKET_ENV="production"
	export ROCKET_ADRESS="127.0.0.1"
	export ROCKET_PORT=8000
	export ADMIN_TOKEN="${ADMIN_TOKEN}"
	#export SIGNUPS_ALLOWED=false
	#export SIGNUPS_DOMAINS_WHITELIST=example.org
	#export DOMAIN=https://bitwarden.example.org
	EOF
fi

## Setting permissions
echo ">>> Setting permissions."
chown -R bitwarden:bitwarden ${BASEDIR} ${DATA_DIR}

if [ -z "$UPDATE" ]; then
	echo ">>> Enabling service bitwarden"
	sysrc "bitwarden_enable=YES"

	echo ">>> Please check ${RC_CONF_D_SCRIPT} for needed modifications and start bitwarden with \"service bitwarden start\" afterwards."
else
	## Start bitwarden_rs
	echo ">>> Starting bitwarden_rs."
	service bitwarden start
fi
