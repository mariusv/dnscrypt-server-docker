#! /bin/sh

KEYS_DIR="/opt/dnscrypt-wrapper/etc/keys"
STKEYS_DIR="${KEYS_DIR}/short-term"

prune() {
    find "$STKEYS_DIR" -type f -cmin +1440 -exec rm -f {} \;
}

rotation_needed() {
    if [ ! -f "${STKEYS_DIR}/dnscrypt.cert" ]; then
        echo true
    else
        if [ $(find "$STKEYS_DIR" -type f -cmin -720 -print -quit | wc -l | sed 's/[^0-9]//g') -le 0 ]; then
            echo true
        else
            echo false
        fi
    fi
}

new_key() {
    ts=$(date '+%s')
    /opt/dnscrypt-wrapper/sbin/dnscrypt-wrapper --gen-crypt-keypair \
        --crypt-secretkey-file="${STKEYS_DIR}/${ts}.key" &&
    /opt/dnscrypt-wrapper/sbin/dnscrypt-wrapper --gen-cert-file \
        --provider-publickey-file="${KEYS_DIR}/public.key" \
        --provider-secretkey-file="${KEYS_DIR}/secret.key" \
        --crypt-secretkey-file="${STKEYS_DIR}/${ts}.key" \
        --provider-cert-file="${STKEYS_DIR}/${ts}.cert" \
        --cert-file-expire-days=1 && \
    mv -f "${STKEYS_DIR}/${ts}.cert" "${STKEYS_DIR}/dnscrypt.cert"
}

stkeys_files() {
    res=""
    for file in $(ls "$STKEYS_DIR"/[0-9]*.key); do
        res="${res}${file},"
    done
    echo "$res"
}

if [ ! -f "$KEYS_DIR/provider_name" ]; then
    exit 1
fi
provider_name=$(cat "$KEYS_DIR/provider_name")

mkdir -p "$STKEYS_DIR"
prune
[ $(rotation_needed) = true ] && new_key

exec /opt/dnscrypt-wrapper/sbin/dnscrypt-wrapper \
    --user=_dnscrypt-wrapper \
    --listen-address=0.0.0.0:443 \
    --resolver-address=127.0.0.1:553 \
    --provider-name="$provider_name" \
    --provider-cert-file="${STKEYS_DIR}/dnscrypt.cert" \
    --crypt-secretkey-file=$(stkeys_files)
