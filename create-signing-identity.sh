#!/usr/bin/env bash
# Create a local self-signed code-signing identity so the camera (TCC) grant survives
# rebuilds. Ad-hoc signing ("-") changes the binary's cdhash every build, which makes macOS
# re-prompt for camera permission each time; a stable named identity fixes that.
#
# Additive + reversible: this only ADDS a cert to your login keychain. Remove later with
#   security delete-identity -c "PrimeEye Self-Signed" ~/Library/Keychains/login.keychain-db
set -euo pipefail

IDENTITY="PrimeEye Self-Signed"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

# Detect by certificate name: a self-signed cert is usable by codesign even though it is
# untrusted and thus hidden from `find-identity -p codesigning`.
if security find-certificate -c "$IDENTITY" >/dev/null 2>&1; then
  echo "✓ identity '$IDENTITY' already present"
  exit 0
fi

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
cat > "$TMP/cs.cnf" <<'CNF'
[ req ]
distinguished_name = dn
x509_extensions    = v3
prompt             = no
[ dn ]
CN = PrimeEye Self-Signed
[ v3 ]
basicConstraints = critical, CA:false
keyUsage         = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
CNF

# Pin /usr/bin/openssl (LibreSSL): a Homebrew OpenSSL 3.x on PATH would emit a PKCS12 that
# the system `security import` (LibreSSL) cannot read.
/usr/bin/openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
  -keyout "$TMP/key.pem" -out "$TMP/cert.pem" -config "$TMP/cs.cnf"
/usr/bin/openssl pkcs12 -export -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
  -name "$IDENTITY" -out "$TMP/id.p12" -passout pass:primeeye

# -T /usr/bin/codesign pre-authorizes codesign to use the private key.
security import "$TMP/id.p12" -k "$KEYCHAIN" -P primeeye -T /usr/bin/codesign

# Make a silent import failure loud (security import can exit 0 without landing the identity).
if ! security find-certificate -c "$IDENTITY" >/dev/null 2>&1; then
  echo "ERROR: import reported success but the cert is not in the keychain" >&2
  exit 1
fi

echo "✓ imported '$IDENTITY' into the login keychain"
echo "  NOTE: the first signed build may pop a keychain dialog - click 'Always Allow'."
security find-identity -v -p codesigning | grep PrimeEye || true
