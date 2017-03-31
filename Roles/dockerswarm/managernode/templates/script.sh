#!/bin/bash
#This script will help you setup Docker for TLS authentication.
# Run it passing in the arguement for the FQDN of your docker server
#
# For example:
#    ./create-docker-tls.sh myhost.docker.com
#
# The script will also create a profile.d (if it exists) entry
# which configures your docker client to use TLS
#
# We will also overwrite /etc/sysconfig/docker (again, if it exists) to configure the daemon.
# A backup will be created at /etc/sysconfig/docker.unixTimestamp
#
# MIT License applies to this script.  I don't accept any responsibility for
# damage you may cause using it.
#

HOSTNAME=${1:-$HOST_LOCAL_IP}
#CERTS_FOLDER=${2:-./tlskey}
echo HOSTNAME $HOSTNAME

set -e
STR=2048
if [ "$#" -gt 0 ]; then
  DOCKER_HOST="$1"
else
  echo " => ERROR: You must specify the docker FQDN as the first arguement to this scripts! <="
  exit 1
fi

if [ "$USER" == "root" ]; then
  echo " => WARNING: You're running this script as root, therefore root will be configured to talk to docker"
  echo " => If you want to have other users query docker too, you'll need to symlink /root/.docker to /theuser/.docker"
fi

echo " => Using Hostname:$HOSTNAME  You MUST connect to docker using this host!"

echo " => Ensuring config directory exists..."
mkdir -p "/etc/docker/keys"
cd /etc/docker/keys

echo " => Verifying ca.srl"
if [ ! -f "ca.srl" ]; then
  echo " => Creating ca.srl"
  echo 01 > ca.srl
fi

#echo " => Generating CA key"
#openssl genrsa \
# -out ca-key.pem $STR

#echo " => Generating CA certificate"
#openssl req \
#  -new \
#  -key ca-key.pem \
#  -sha256 \
#  -nodes \
#  -subj "/CN=${HOSTNAME}" \
#  -x509 \
#  -days 365 \
#  -out ca.pem

echo " => Generating server key"
openssl genrsa \
  -out server-key.pem $STR

echo " => Generating server CSR"
openssl req \
  -subj "/CN=$HOSTNAME \
  -sha256 \
  -new \
  -key server-key.pem \
  -out server.csr

echo extendedKeyUsage = serverAuth > extfile.cnf
echo " => Signing server CSR with CA"
openssl x509 \
  -req \
  -days 365 \
  -sha256 \
  -in server.csr \
  -CA ca.pem \
  -CAkey ca-key.pem \
  -out server-cert.pem \
  -extfile extfile.cnf

echo " => Generating client key"
openssl genrsa \
  -out key.pem $STR

echo " => Generating client CSR"
openssl req \
  -subj "/CN={$HOSTNAME}" \
  -new \
  -key key.pem \
  -out client.csr

echo " => Creating extended key usage"
echo extendedKeyUsage = clientAuth > extfile.cnf
 
echo " => Signing client CSR with CA"
openssl x509 \
  -req \
  -days 365 \
  -sha256 \
  -in client.csr \
  -CA ca.pem \
  -CAkey ca-key.pem \
  -out cert.pem \
  -extfile extfile.cnf
rm -v client.csr server.csr

chmod -v 0400 ca-key.pem key.pem server-key.pem

chmod -v 0444 ca.pem server-cert.pem cert.pem

cp -rp  ca.pem ${CERTS_FOLDER}/ca.pem
