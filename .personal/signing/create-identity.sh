#!/bin/bash
# Creates this edition's signing identity, "Tinycast Self-Signed", once, on your Mac.
# It writes only this identity, to a folder you choose; nothing else in your keychain is exported.
# usage: .personal/signing/create-identity.sh [output-folder]   (default: ~/Desktop/tinycast-signing)
set -euo pipefail
OUT="${1:-$HOME/Desktop/tinycast-signing}"
if [ -e "$OUT/tinycast-signing.p12" ]; then
  echo "$OUT/tinycast-signing.p12 already exists. Keep using it: a new identity strands installed copies." >&2
  exit 1
fi
mkdir -p "$OUT"
chmod 700 "$OUT"
umask 077
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
PASSWORD="$(/usr/bin/openssl rand -base64 24 | tr -d '/+=' | cut -c1-24)"

# A ten-year, code-signing-only certificate; LibreSSL's PKCS#12 defaults are what macOS imports.
/usr/bin/openssl req -x509 -newkey rsa:3072 -nodes -days 3650 \
  -keyout "$WORK/key.pem" -out "$WORK/cert.pem" -subj "/CN=Tinycast Self-Signed" \
  -addext "basicConstraints=critical,CA:false" -addext "keyUsage=critical,digitalSignature" \
  -addext "extendedKeyUsage=critical,codeSigning" 2> /dev/null
/usr/bin/openssl pkcs12 -export -inkey "$WORK/key.pem" -in "$WORK/cert.pem" -name "Tinycast Self-Signed" \
  -out "$OUT/tinycast-signing.p12" -passout "pass:$PASSWORD"
printf '%s' "$PASSWORD" > "$OUT/SIGNING_P12_PASSWORD.txt"
base64 < "$OUT/tinycast-signing.p12" | tr -d '\n' > "$OUT/SIGNING_P12_BASE64.txt"
/usr/bin/openssl x509 -in "$WORK/cert.pem" -outform der | shasum -a 256 | cut -d' ' -f1 > "$OUT/certificate.sha256"

cat << INFO

Created in $OUT:
  tinycast-signing.p12        the identity (private key + certificate): back it up, keep it secret
  SIGNING_P12_PASSWORD.txt    its password: store it with the backup, e.g. in a password manager
  SIGNING_P12_BASE64.txt      the value of the SIGNING_P12_BASE64 repository secret
  certificate.sha256          the public fingerprint each release prints, to compare

Next (see .personal/SIGNING.md):
  1. GitHub › sylvarg/tinycast-history › Settings › Secrets and variables › Actions › New secret:
     SIGNING_P12_BASE64 = contents of SIGNING_P12_BASE64.txt
     SIGNING_P12_PASSWORD = contents of SIGNING_P12_PASSWORD.txt
  2. Back up tinycast-signing.p12 and its password somewhere safe and offline.
  3. Delete SIGNING_P12_BASE64.txt and SIGNING_P12_PASSWORD.txt once the secrets and backup exist.
INFO
