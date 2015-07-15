#!/usr/bin/env bash
#
# Tool:    
#	TLSSLed.sh
#
# Description:
#	Script to extract the most relevant security details from a 
#	target SSL/TLS HTTPS implementation by using sslscan & openssl.
#
# URL:     
#	http://www.taddong.com/en/lab.html#TLSSLED
#
# Author:  
#	Raul Siles (raul _AT_ taddong _DOT_ com)
#	Taddong SL (www.taddong.com)
#
# Date:		2013-01-31
# Version:	1.3
#

#
# /**************************************************************************
# *   Copyright 2011-2013 by Taddong SL (Raul Siles)                        *
# *                                                                         *
# *   This program is free software; you can redistribute it and/or modify  *
# *   it under the terms of the GNU General Public License as published by  *
# *   the Free Software Foundation; either version 3 of the License, or     *
# *   (at your option) any later version.                                   *
# *                                                                         *
# *   This program is distributed in the hope that it will be useful,       *
# *   but WITHOUT ANY WARRANTY; without even the implied warranty of        *
# *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *
# *   GNU General Public License for more details.                          *
# *                                                                         *
# *   You should have received a copy of the GNU General Public License     *
# *   along with this program. If not, see <http://www.gnu.org/licenses/>.  *
# *                                                                         *
# **************************************************************************/
#

#
# - TODO:
#   - Add a new command line argument to define the specific URL to test in
#   the target server. E.g. $ ./TLSSLed.sh HOSTNAME_or_IP-ADDRESS PORT [URL]"
#
#   By default the URL should be "/".
#   This check should use HTTP/1.1 (instead of 1.0) and a valid Host header.
#   (Right now this only applies to the HTTP header tests at the end)
#
#
# - New in version 1.3:
#   - All file output goes to a single directory (same filenames as in 
#     previous versions) instead of to the working local directory.
#   - Change in the date format used for log files:
#     From: 2011-12-30_105055 - To: 20111230-105055
#   - Test if SSL/TLS renegotiation is enabled (NEW check) and if the target 
#     service supports secure renegotiation (already in previous versions).
#     If secure renegotiation is not supported, we must check renegotiation
#     by usin legacy renegotiation (two new log files are used). 
#   - New test to check for legacy renegotiation even when secure 
#     renegotiation is supported, just in case the target service supports
#     both.
#   - Test if client certificate authentication is required by the target 
#     service. If so, identify the number of CAs accepted and save the
#     list of CAs to a file.
#	- New test to check for HTTP headers using HTTP/1.0 (previous 
#	  versions) as well as HTTP/1.1 and a valid Host header. New log 
#	  files created for this.
#   - New error handling code for the initial SSL/TLS verification.
#   - Optimizations in the openssl delays (sleep timers). 
#   - New DELAY variable to control sleep timers (by default 3 seconds - 
#     it was 5 before).
#   - New output indentation.
#   - New output code set for findings: - (negative), + (positive), . (info),
#     * (group of checks) or ! (error/warning).
#   - LOGFILE changed to SSLSCANLOGFILE & ERRFILE changed to SSLSCANERRFILE.
#   - RENEGLEGACY???FILE(s) included in the final listing and removal 
#     process.
#   - Several changes to the output messages for the different findings.
#   - Duplication of "Prefered Server Cipher" output message removed.
#   - New check to test for RC4 in the prefered chiper(s) regarding BEAST.
#   - Use of openssl "-prexit" option for some weird target scenarios (CSA).
#   - Added the date and time at the beggining of the output.
#
# - New in version 1.2:
#   - Mac OS X support: sed regex switch changed - by [ anonymous ].
#   - Test if target service speaks SSL/TLS - by Abraham Aranguren (AA).
#     For performance reasons, this test has been merged with the SSL/TLS 
#     renegotiation test.
#   - Optimizations by removing cat usage in grepping for findings - by AA.
#   - New initial tests to check for the tool prerequisites: openssl & 
#     sslscan.
#   - Test for TLS v1.1 and v1.2 support (CVE-2011-3389 aka BEAST).
#     The tests also include checking for SSLv3 and TLSv1 support.
#   - Log files names changed from host:port to host_port and ":" removed 
#     from the time portion of the date command, to be able to copy them 
#     to Windows based file systems: 
#     (In Windows ":" is not allowed in a filename, while "_" is).
#
# - New in version 1.1:
#   - Cert public key length, subject, issuer, and validiy period.
#   - Test HTTP(S) secure headers: Strict-Transport-Security (STS), and 
#     cookies with and without the secure flag.
#   - NOTE: openssl output is now saved to files too.
#
# - Current SSL/TLS tests: (version 1.0)
#   SSLv2, NULL cipher, weak ciphers -key length-, strong ciphers -AES-, 
#   MD5 signed cert, and SSL/TLS renegotiation.
#
#
# Requires: 
# - sslscan
# https://sourceforge.net/projects/sslscan/
# - openssl
# http://www.openssl.org
#
# Credits for ideas and feedback: 
# - Version 1.0 based on ssl_test.sh by Aung Khant, http://yehg.net.
# - Abraham Aranguren (AA) - http://securityconscious.blogspot.com  (in v1.2)
# 

# New output codeset (between square brackets) for the findings:
# [-] Negative finding (insecure)
# [+] Positive finding (secure)
# [.] Informational finding 
# [*] Group of checks
# [!] Error or warning message

# Variables

# Version
VERSION=1.3

# Manage sleep time for openssl connections (in seconds)
DELAY=3

# DATE (pre v1.3):
# DATE=$(date +%F_%R:%S | sed 's/://g')
# DATE (post v1.3+):
DATE=$(date +%Y%m%d-%H%M%S)

# Some SSL/TLS target services require some extra options to work:
# E.g. -prexit: Print out info even when the SSL/TLS connection fails.
#               http://www.openssl.org/docs/apps/s_client.html
#               For some scenarios where client certificates are required.
OPENSSLOPTIONS="-prexit"

# Default openssl protocol: By default this variable is empty so that the 
# protocol is automatically selected by the openssl version available:
OPENSSLPROTOCOLVERSION=""
# The default backward compatible protocol version in case of errors: TLS1
BACKWARDPROTOCOL="false"
OPENSSLBACKWARDPROTOCOLVERSION="-tls1"
#
# See NOTE (openssl protocol version glitches) below. 
#
# openssl 1.x might require the "-tls1" or "-ssl3" openssl command line 
# arguments on some target sites, as openssl 1.x uses TLS protocol version 
# 1.2 by default in the Client Hello message, and if not supported by the 
# target server, it never sends the Server Hello message back.
#

# *** SECURITY DISCLAIMER ***
# This script does not filter the input for certain commands, hence it 
# might be vulnerable to local input command manipulation, such as in uname.
# *** SECURITY DISCLAIMER ***

# Functions ()

reviewlogfiles () {
	echo
	echo "[.] Review the files within the output directory for more info."
	echo "    [.] Output directory: $DIRECTORY ..." 
	echo
}

# Function to initially test if the target service speaks SSL/TLS
test_if_service_speaks_SSLTLS () {

	(echo R; sleep $DELAY) | \
	openssl s_client $OPENSSLPROTOCOLVERSION -connect $HOST:$PORT \
	$OPENSSLOPTIONS > $DIRECTORY/$RENEGLOGFILE 2> $DIRECTORY/$RENEGERRFILE &
	pid=$!
	sleep $DELAY

	SSL_HANDSHAKE_LINES=$(cat $DIRECTORY/$RENEGLOGFILE | wc -l)
	#
	# NOTE: openssl protocol version glitches
	#
	# This check does not work with openssl 1.0.1-dev on some target sites, 
	# and it requires the "-tls1" or "-ssl3" openssl command line arguments; 
	# here, and in all openssl instances within this script.
	#
	# The reason is openssl 1.0.1-dev uses TLS protocol version 1.2 in the 
	# Client Hello message, and the server never sends the Server Hello 
	# message. The otput simply shows:
	# CONNECTED
	# 
	# If the -tls1_1 switch is used in these target services, they properly 
	# reply back with a "wrong version number" message.
	#
	# v1.3: Added new code to accommodate this scenario:
	# If (-lt 5) but CONNECTED, then use the -tls1 (backward protocol 
	# version) switch in all openssl executions...
	# ... or (select the right option based on the openssl version, but this
	# might change): if openssl 1.0.1-dev or +, use -tls1...

	#
	# There is a specific case where the target service can refuse the 
	# connection but the port still speaks SSL/TLS. In that case the error 
	# log contains the following messages, although the handshake log is > 
	# than 5 lines:
	# connect: Connection refused
	# connect:errno=22
	#

	ERR_SSL=$(cat $DIRECTORY/$RENEGERRFILE)

	if grep -q "connect: Connection refused" <<<$ERR_SSL; then
		# Target service speaks SSL/TLS but refuses the connection
		echo
		echo "[!] ERROR: The target service $HOST:$PORT might speak SSL/TLS"
		echo "           but refuses the connection."
		reviewlogfiles
		exit
	fi

	if [ $SSL_HANDSHAKE_LINES -lt 5 ] ; then 
		# SSL handshake failed - Non SSL/TLS service or error:
		# - If the target service does not speak SSL/TLS, openssl does not 
		#   terminate, so kill it.
		# - However, if the target speaks SSL/TLS but the connection fails 
		#   (e.g. "sslv3 alert bad certificate") then the connection 
		#   finishes.
		kill -s SIGINT ${pid} 2>/dev/null

		# Check if it failed because of an error or lack of SSL/TLS support
		#ERR_SSL=$(cat $DIRECTORY/$RENEGERRFILE)
		if grep -q "ssl handshake failure" <<<$ERR_SSL; then
		    echo
		    echo "[!] ERROR: The target service $HOST:$PORT speaks SSL/TLS"
			echo "           but returned an error: ssl handshake failure."
			echo "           E.g. Client certificate mandatory?"
		elif [ $BACKWARDPROTOCOL == "true" ]; then
			echo
			echo "[!] ERROR: The target service $HOST:$PORT does not seem"
			echo "           to speak SSL/TLS even when using the SSL/TLS backward"
			echo "           protocol version: $OPENSSLPROTOCOLVERSION"
		elif grep -q "CONNECTED" <<<$ERR_SSL; then
			# The local openssl tool tried by default a protocol version not 
			# supported by the target server. Switching back to a more
			# conservative protocol version (OPENSSLBACKWARDPROTOCOLVERSION).
			OPENSSLPROTOCOLVERSION=$OPENSSLBACKWARDPROTOCOLVERSION
			# Set we already tried a backward option
			BACKWARDPROTOCOL="true"
			echo
			echo "[.] WARNING: Trying connection again with SSL/TLS protocol version:"
			echo "             $OPENSSLPROTOCOLVERSION"
			#echo
			mv $DIRECTORY/$RENEGLOGFILE $DIRECTORY/$RENEGLOGFILE.1st-try
			mv $DIRECTORY/$RENEGERRFILE $DIRECTORY/$RENEGERRFILE.1st-try
		    	# Repeat initial test with a potentially different 
			# $OPENSSLPROTOCOLVERSION
			test_if_service_speaks_SSLTLS
		else
		    echo
		    echo "[!] ERROR: The target service $HOST:$PORT does not seem"
			echo "           to speak SSL/TLS or it is not reachable!!"
		fi
		reviewlogfiles
		exit
	else 
		# Specific case where server returns "reason(1000)" cause it requires a
		# client certificate, and SSLv3 was used by default. Force it to switch
		# to the OPENSLLBACKWARDPROTOCOLVERSION and try again:
		# Error: 
		# 3073591496:error:140773E8:SSL routines:SSL23_GET_SERVER_HELLO:\
		# reason(1000):s23_clnt.c:724:
	        # Another error: (!= openssl version)
		# 13531:error:14094412:SSL routines:SSL3_READ_BYTES:sslv3 alert bad certificate:s3_pkt.c:1093:SSL alert number 42

		if grep -q "SSL23_GET_SERVER_HELLO:reason(1000)\|sslv3 alert bad certificate" <<<$ERR_SSL; then
		    echo
		    echo "[!] ERROR: The target service $HOST:$PORT speaks SSL/TLS"
		    echo "           but returned an error."
		    echo "           Check the output and try manually other SSL/TLS versions."
		    echo "           E.g. Client certificate mandatory?"
		    reviewlogfiles
		    exit
		else	
		    # SSL handshake succeded - Continue...
		    # VERBOSE
		    echo "    [.] The target service $HOST:$PORT seems to speak SSL/TLS..."
		    echo
		    echo "    [.] Using SSL/TLS protocol version: $OPENSSLPROTOCOLVERSION"
		    echo "        (empty means I'm using the default openssl protocol version(s))"
		    echo
		fi
	fi
}


# MAIN:

# v1.2: 
# Mac OS X (Darwin) support:
# sed regexes in Linux use the -r switch, while in non-GNU systems (like
# Mac OS X) they use the -E switch.
#SED_ARG_REGEX=-r
#if [ "$(uname)" == "Darwin" ] ; then
#   SED_ARG_REGEX=-E
#fi
#
# Used for the old check below required to remove terminal output formatting

echo ------------------------------------------------------
echo " TLSSLed - ($VERSION) based on sslscan and openssl"
echo "                 by Raul Siles (www.taddong.com)"
echo ------------------------------------------------------

if [ -z `which openssl` ] ;then echo; echo "[!] ERROR: openssl command not found!"; echo; exit; fi
if [ -z `which sslscan` ] ;then echo; echo "[!] ERROR: sslscan command not found!"; echo; exit; fi

OPENSSLVERSION=$(openssl version)
#SSLSCANVERSION=$(sslscan --version | grep version | \
#sed ${SED_ARG_REGEX} "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g")
# v1.3:
# Works with the old sslscan 1.8.2 and the new 1.8.3rc3 fork
SSLSCANVERSION=$(sslscan --version | grep version | \
sed "s/^.*sslscan/sslscan/")

echo "    openssl version: $OPENSSLVERSION"
echo "    $SSLSCANVERSION"
echo ------------------------------------------------------
echo "    Date: $DATE" 
echo ------------------------------------------------------
echo

if [ $# -ne 2 ]; then 
   echo "[!] Usage: $0 <hostname or IP_address> <port>"
   echo
   exit
fi

HOST=$1
PORT=$2

echo "[*] Analyzing SSL/TLS on $HOST:$PORT ..."

# Run sslcan once, store the results to a log file and
# analyze that file for all the different tests:
TARGET=$HOST\_$PORT
DIRECTORY=TLSSLed\_$VERSION\_$TARGET\_$DATE
SSLSCANLOGFILE=sslscan\_$TARGET\_$DATE.log
SSLSCANERRFILE=sslscan\_$TARGET\_$DATE.err
# Same idea for openssl - save results to files and analyze
# them to verify different tests:
RENEGLOGFILE=openssl\_RENEG\_$TARGET\_$DATE.log
RENEGERRFILE=openssl\_RENEG\_$TARGET\_$DATE.err
RENEGLEGACYLOGFILE=openssl\_RENEG\_LEGACY\_$TARGET\_$DATE.log
RENEGLEGACYERRFILE=openssl\_RENEG\_LEGACY\_$TARGET\_$DATE.err
HEADLOGFILE=openssl\_HEAD\_$TARGET\_$DATE.log
HEADERRFILE=openssl\_HEAD\_$TARGET\_$DATE.err
HEAD1LOGFILE=openssl\_HEAD\_1.0\_$TARGET\_$DATE.log
HEAD1ERRFILE=openssl\_HEAD\_1.0\_$TARGET\_$DATE.err
CASFILE=CAs-client-cert\_$TARGET\_$DATE.txt


# Just in case...
if [ -z "$DIRECTORY" ]; then
    echo
    echo "[!] ERROR: Output directory is not defined! Aborting execution!"
    echo
    exit 
fi

# VERBOSE
echo "    [.] Output directory: $DIRECTORY ..." 
if [ -d "$DIRECTORY" ]; then
    echo
    echo "[!] ERROR: Output directory already exist! Aborting execution!"
    echo
    exit 
fi
echo
mkdir -p $DIRECTORY

# Check if the target service speaks SSL/TLS (& check renegotiation)
echo "[*] Checking if the target service speaks SSL/TLS..." 

test_if_service_speaks_SSLTLS

# This initial check is required because sslscan works pretty slow & badly
# on non-SSL/TLS services, such as HTTP (without S):

echo "[*] Running sslscan on $HOST:$PORT ..."
sslscan $HOST:$PORT > $DIRECTORY/$SSLSCANLOGFILE \
2> $DIRECTORY/$SSLSCANERRFILE

echo
echo "    [-] Testing for SSLv2 ..."
grep "Accepted  SSLv2" $DIRECTORY/$SSLSCANLOGFILE
echo
echo "    [-] Testing for the NULL cipher ..."
grep "NULL" $DIRECTORY/$SSLSCANLOGFILE | grep Accepted
echo
echo "    [-] Testing for weak ciphers (based on key length - 40 or 56 bits) ..."
grep " 40 bits" $DIRECTORY/$SSLSCANLOGFILE | grep Accepted
grep " 56 bits" $DIRECTORY/$SSLSCANLOGFILE | grep Accepted
echo
echo "    [+] Testing for strong ciphers (based on AES) ..."
grep "AES" $DIRECTORY/$SSLSCANLOGFILE | grep Accepted

echo 
echo "    [-] Testing for MD5 signed certificate ..."
#cat $DIRECTORY/$SSLSCANLOGFILE | grep -E 'MD5WithRSAEncryption|md5WithRSAEncryption'
grep -i 'MD5WithRSAEncryption' $DIRECTORY/$SSLSCANLOGFILE

echo 
echo "    [.] Testing for the certificate public key length ..."
grep -i 'RSA Public Key' $DIRECTORY/$SSLSCANLOGFILE

echo 
echo "    [.] Testing for the certificate subject ..."
grep -i 'Subject:' $DIRECTORY/$SSLSCANLOGFILE

echo 
echo "    [.] Testing for the certificate CA issuer ..."
grep -i 'Issuer:' $DIRECTORY/$SSLSCANLOGFILE

echo 
echo "    [.] Testing for the certificate validity period ..."
NOW=$(date -u)
echo "    Today: $NOW"
grep -i 'Not valid' $DIRECTORY/$SSLSCANLOGFILE

echo 
echo "    [.] Checking preferred server ciphers ..."
# v1.1:
# cat $DIRECTORY/$SSLSCANLOGFILE | sed '/Prefered Server Cipher(s):/,/^$/!d' | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g"
#
PREFERED_CIPHERS=$(cat $DIRECTORY/$SSLSCANLOGFILE | \
sed '/Prefered Server Cipher(s):/,/^$/!d' | \
sed ${SED_ARG_REGEX} "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g" | \
grep -v "Prefered Server Cipher" | grep -v "^$")
echo "$PREFERED_CIPHERS"

# Extra empty line above removed with the last grep

#
# SSL/TLS RENEGOTIATION TESTS:
# -----------------------------
#
# Before testing for client initiated renegotiation, we need to check if
# we must use the secure (RFC5746) or the insecure (legacy) mode.
#
# Renegotiation details will go to stderr (2>).
#
# If $OPENSSLVERSION is updated (0.9.8m+) it supports RFC5746 and will print
# the details based on the analysis of the new RI extension:
# - Secure Renegotiation IS NOT supported
# - Secure Renegotiation IS supported
#
# Command executed initially to check if target service supports SSL/TLS:
#
# (echo R; sleep $DELAY) | openssl s_client $OPENSSLPROTOCOLVERSION -connect $HOST:$PORT > \
# $DIRECTORY/$RENEGLOGFILE 2> $DIRECTORY/$RENEGERRFILE
#
# v1.3: 
# First of all, check if secure renegotiation is supported. Based on the 
# results, check if client initiated renegotiation is enabled by using 
# openssl defaults (secure) or the use the "-legacy_renegotiation" flag 
# (insecure).
#
# It is important to differentiate between having client initiated 
# renegotiation enabled, and having support for secure renegotiation.
# There are four possible options or combinations.
#
# If secure renegotiation is NOT supported, we need to use the legacy flag
# to test for SSL/TLS legacy renegotiation. If it IS supported, the default 
# command (initially executed) works fine.
# 
# Additionally, even if secure renegotiation IS supported, we can check if
# the target service also accepts insecure renegotiations (legacy). 
# Therefore, in any case we test for SSL/TLS renegotiation using the legacy 
# mode.
#

# The text can appear two times, hence we use "uniq":
SECURE_RENEG=$(grep -E "Secure Renegotiation IS" $DIRECTORY/$RENEGLOGFILE | \
uniq)

echo
echo "[*] Testing for SSL/TLS renegotiation MitM vuln. (CVE-2009-3555) ..."
echo
echo "    [+] Testing for secure renegotiation support (RFC 5746) ..."
echo "    $SECURE_RENEG"

# Check for SSL/TLS renegotiation using legacy mode in any case
LEGACY_RENEG="-legacy_renegotiation"
(echo R; sleep $DELAY) | \
openssl s_client $LEGACY_RENEG $OPENSSLPROTOCOLVERSION -connect $HOST:$PORT \
> $DIRECTORY/$RENEGLEGACYLOGFILE 2> $DIRECTORY/$RENEGLEGACYERRFILE 

echo
echo "[*] Testing for SSL/TLS renegotiation DoS vuln. (CVE-2011-1473) ..."
echo

if grep -q NOT <<<$SECURE_RENEG; then
    # Secure renegotiation IS NOT supported: show legacy mode results
    SECURE_RENEG_STATE="No"
    ERR_RENEG=$(cat $DIRECTORY/$RENEGLEGACYERRFILE)
    echo "    [.] Testing for client initiated (CI) SSL/TLS renegotiation (insecure)..."
else
    # Secure renegotiation IS supported: RFC5746
    # The default option in openssl (assuming 0.9.8m+) is not to use any 
    # special flag, that is, use secure renegotiation by default
    SECURE_RENEG_STATE="Yes"
    ERR_RENEG=$(cat $DIRECTORY/$RENEGERRFILE)
    echo "    [.] Testing for client initiated (CI) SSL/TLS renegotiation (secure)..."
fi

# - If SSL/TLS renegotiation is enabled you will get:
# ...
# verify return:0
# DONE
#
# The DONE message is on the error output, not on the standard output, and
# only when the "echo R & sleep" method is used (not in interactive mode).

if grep -q DONE <<<$ERR_RENEG; then
    echo "    (CI) SSL/TLS renegotiation IS enabled"
# Client certificate might be required: 
elif grep -q "sslv3 alert bad certificate" <<<$ERR_RENEG; then
    echo "    UNKNOWN: Client certificate might be required (sslv3 alert bad certificate)"
# Client certificate might be required: 
# "sslv3 alert unexpected message" in openssl-1.0.1-dev
elif grep -q "sslv3 alert unexpected message" <<<$ERR_RENEG; then
    echo "    UNKNOWN: Client certificate might be required (sslv3 alert unexpected message)"
# Different error behaviors when reneg. is not enabled:
elif grep -q "no renegotiation" <<<$ERR_RENEG; then
    echo "    (CI) SSL/TLS renegotiation IS NOT enabled (no renegotiation)"
elif grep -q "ssl handshake failure" <<<$ERR_RENEG; then
    echo "    (CI) SSL/TLS renegotiation IS NOT enabled (ssl handshake failure)"
else
    echo "    UNKNOWN"
fi

# Additionally, if secure renegotiation is supported, check if it still
# allows renegotiation using legacy mode (insecure):
if [ "$SECURE_RENEG_STATE" == "Yes" ]; then
    echo
    echo "    [.] Testing for client initiated (CI) SSL/TLS renegotiation (insecure)..."
    ERR_RENEG=$(cat $DIRECTORY/$RENEGLEGACYERRFILE)

    # REPEAT:
    if grep -q DONE <<<$ERR_RENEG; then
        echo "    (CI) SSL/TLS renegotiation IS enabled"
    # Client certificate might be required: 
    elif grep -q "sslv3 alert bad certificate" <<<$ERR_RENEG; then
        echo "    UNKNOWN: Client certificate might be required (sslv3 alert bad certificate)"
    # Client certificate might be required: 
    # "sslv3 alert unexpected message" in openssl-1.0.1-dev
    elif grep -q "sslv3 alert unexpected message" <<<$ERR_RENEG; then
        echo "    UNKNOWN: Client certificate might be required (sslv3 alert unexpected message)"
    # Different error behaviors when reneg. is not enabled:
    elif grep -q "no renegotiation" <<<$ERR_RENEG; then
        echo "    (CI) SSL/TLS renegotiation IS NOT enabled (no renegotiation)"
    elif grep -q "ssl handshake failure" <<<$ERR_RENEG; then
        echo "    (CI) SSL/TLS renegotiation IS NOT enabled (ssl handshake failure)"
    else
        echo "    UNKNOWN"
    fi
fi

# Check if client certificate autentication is required by the target 
# service.
#
# NOTE: If client certificate authentication is being requested, it would be
# possible to test for it using a client digital certificate using openssl:
# $ openssl s_client $OPENSSLPROTOCOLVERSION -connect www.example.com:443 \
#   -cert client.pem -key client.key
#

LOG_RENEG=$(cat $DIRECTORY/$RENEGLOGFILE)

echo
echo "[*] Testing for client authentication using digital certificates ..."
echo
if grep -q "Acceptable client certificate CA names" <<<$LOG_RENEG; then
    echo "    SSL/TLS client certificate authentication IS required"

    # Check the list and number of accepted CAs
    # Save CAs list to file
    # The LOG_RENEG variable does not have the original break lines to parse
    # the output properly, so read the file again
    cat $DIRECTORY/$RENEGLOGFILE | \
	sed '/Acceptable client certificate CA names/,/^---$/!d' | \
	grep -v "\-\-\-" | grep -v "Acceptable client certificate CA names" | \
	grep -v "^$" > $DIRECTORY/$CASFILE
    
    # Number of CAs
    CAS=$(cat $DIRECTORY/$CASFILE | wc -l)
    echo "    The target service accepts $CAS Certification Authorities (CAs)"

elif grep -q "No client certificate CA names sent" <<<$LOG_RENEG; then
    echo "    SSL/TLS client certificate authentication IS NOT required"
else
    echo "    UNKNOWN"
fi


echo
echo "[*] Testing for TLS v1.1 and v1.2 (CVE-2011-3389 vuln. aka BEAST) ..."

# Test for SSLv3 and TLSv1 support first (from sslscan)
echo
echo "    [-] Testing for SSLv3 and TLSv1 support ..."
grep "Accepted  SSLv3" $DIRECTORY/$SSLSCANLOGFILE
grep "Accepted  TLSv1" $DIRECTORY/$SSLSCANLOGFILE

# Test for RC4 in the list of prefered ciphers (from sslscan previously)
echo
echo "    [+] Testing for RC4 in the prefered cipher(s) list ..."
echo "$PREFERED_CIPHERS" | grep "RC4"

#
# Connection details go to stderr (2>) and, in this case, to a variable:
#
# If $OPENSSLVERSION is updated (version >= 1.0.1-stable) it supports 
# TLS v1.1 & v1.2, if not, the openssl help is displayed in the command 
# output.
#
OUTPUT_TLS1_1=$((echo Q; sleep $DELAY) | \
openssl s_client -tls1_1 -connect $HOST:$PORT 2>&1)
OUTPUT_TLS1_2=$((echo Q; sleep $DELAY) | \
openssl s_client -tls1_2 -connect $HOST:$PORT 2>&1)

#      if "DONE":                   TLS v1.x supported
# else if "wrong version number":   TLS v1.x not supported
# else if "unknown option":         OpenSSL does not support TLS v1.1 or v1.2

echo
echo "    [.] Testing for TLS v1.1 support ..."

if grep -q DONE <<<$OUTPUT_TLS1_1; then
    echo "    TLS v1.1 IS supported"
elif grep -q "wrong version number" <<<$OUTPUT_TLS1_1; then
    echo "    TLS v1.1 IS NOT supported"
elif grep -q "ssl handshake failure" <<<$OUTPUT_TLS1_1; then
    echo "    TLS v1.1 IS NOT supported (ssl handshake failure)"
elif grep -q "unknown option" <<<$OUTPUT_TLS1_1; then
    echo "    The local openssl version does NOT support TLS v1.1"
else
    echo "    UNKNOWN"
fi

echo
echo "    [.] Testing for TLS v1.2 support ..."

if grep -q DONE <<<$OUTPUT_TLS1_2; then
    echo "    TLS v1.2 IS supported"
elif grep -q "wrong version number" <<<$OUTPUT_TLS1_2; then
    echo "    TLS v1.2 IS NOT supported"
elif grep -q "ssl handshake failure" <<<$OUTPUT_TLS1_2; then
    echo "    TLS v1.2 IS NOT supported (ssl handshake failure)"
elif grep -q "unknown option" <<<$OUTPUT_TLS1_2; then
    echo "    The local openssl version does NOT support TLS v1.2"
else
    echo "    UNKNOWN"
fi

echo
echo "[*] Testing for HTTPS (SSL/TLS) security headers using HTTP/1.0 ..."

(echo -e "HEAD / HTTP/1.0\n\n"; sleep $DELAY) | \
openssl s_client $OPENSSLPROTOCOLVERSION -connect $HOST:$PORT \
> $DIRECTORY/$HEAD1LOGFILE 2> $DIRECTORY/$HEAD1ERRFILE

echo
echo "    [+] Testing for HTTP Strict-Transport-Security (HSTS) header ..."
grep -i 'Strict-Transport-Security' $DIRECTORY/$HEAD1LOGFILE

echo
echo "    [+] Testing for cookies with the secure flag ..."
grep -i 'Set-Cookie' $DIRECTORY/$HEAD1LOGFILE | grep -i 'secure'

echo
echo "    [-] Testing for cookies without the secure flag ..."
grep -i 'Set-Cookie' $DIRECTORY/$HEAD1LOGFILE | grep -v -i 'secure'


echo
echo "[*] Testing for HTTPS (SSL/TLS) security headers using HTTP/1.1 & Host ..."

(echo -e "HEAD / HTTP/1.1\nHost: $HOST\n\n"; sleep $DELAY) | \
openssl s_client $OPENSSLPROTOCOLVERSION -connect $HOST:$PORT \
> $DIRECTORY/$HEADLOGFILE 2> $DIRECTORY/$HEADERRFILE

echo
echo "    [+] Testing for HTTP Strict-Transport-Security (HSTS) header ..."
grep -i 'Strict-Transport-Security' $DIRECTORY/$HEADLOGFILE

echo
echo "    [+] Testing for cookies with the secure flag ..."
grep -i 'Set-Cookie' $DIRECTORY/$HEADLOGFILE | grep -i 'secure'

echo
echo "    [-] Testing for cookies without the secure flag ..."
grep -i 'Set-Cookie' $DIRECTORY/$HEADLOGFILE | grep -v -i 'secure'


echo
echo "[*] New files created:"
echo "    [.] Output directory: $DIRECTORY ..." 
echo

# Moved to bottom:
#ls -l $DIRECTORY/$SSLSCANLOGFILE
#ls -l $DIRECTORY/$RENEGLOGFILE
#ls -l $DIRECTORY/$RENEGLEGACYLOGFILE
#ls -l $DIRECTORY/$HEAD1LOGFILE
#ls -l $DIRECTORY/$HEADLOGFILE

# Delete all empty error files:
# $ find . -size 0 -name '*.err' -delete 
# This could potentially delete other .err zero-size files not created by 
# TLSSLed.


if [ ! -s "$DIRECTORY/$SSLSCANERRFILE" ]; then
	# SSLscan error file is empty
	rm "$DIRECTORY/$SSLSCANERRFILE"
fi
if [ ! -s "$DIRECTORY/$RENEGERRFILE" ]; then
	# Renegotiation error file is empty
	rm "$DIRECTORY/$RENEGERRFILE"
fi
if [ ! -s "$DIRECTORY/$RENEGLEGACYERRFILE" ]; then
	# Legacy renegotiation error file is empty
	rm "$DIRECTORY/$RENEGLEGACYERRFILE"
fi
if [ ! -s "$DIRECTORY/$HEAD1ERRFILE" ]; then
	# Openssl HEAD 1.0 error file is empty
	rm "$DIRECTORY/$HEAD1ERRFILE"
fi
if [ ! -s "$DIRECTORY/$HEADERRFILE" ]; then
	# Openssl HEAD 1.1 error file is empty
	rm "$DIRECTORY/$HEADERRFILE"
fi

ls $DIRECTORY

echo 
echo [*] done
echo

