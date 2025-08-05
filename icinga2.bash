set -e
cd /var/lib/icinga2

if ! [ -e ca/ca.crt ]; then
  icinga2 pki new-ca
fi

mkdir -p certs
cp ca/ca.crt certs
