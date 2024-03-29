#!/bin/bash

# Helper function to output error messages to STDERR, with red text
error() {
    (set +x; tput -Tscreen bold
    tput -Tscreen setaf 1
    echo $*
    tput -Tscreen sgr0) >&2
}

# Helper function that sifts through /etc/nginx/conf.d/, looking for lines that
# contain ssl_certificate_key, and try to find domain names in them.  We accept
# a very restricted set of keys: Each key must map to a set of concrete domains
# (no wildcards) and each keyfile will be stored at the default location of
# /etc/letsencrypt/live/<primary_domain_name>/privkey.pem
parse_domains() {
    # For each configuration file in /etc/nginx/conf.d/*.conf*
    for conf_file in /etc/nginx/conf.d/*.conf*; do
        sed -n -r -e 's&^\s*ssl_certificate_key\s*\/etc/letsencrypt/live/(.*)/privkey.pem;\s*(#.*)?$&\1&p' $conf_file | xargs echo
    done
}

# Given a config file path, spit out all the ssl_certificate_key file paths
parse_keyfiles() {
    sed -n -e 's&^\s*ssl_certificate_key\s*\(.*\);&\1&p' "$1"
}

# Given a config file path, return 0 if all keyfiles exist (or there are no
# keyfiles), return 1 otherwise
keyfiles_exist() {
    for keyfile in $(parse_keyfiles $1); do
	    currentfile=${keyfile//$'\r'/}
        if [ ! -f $currentfile ]; then
            echo "Couldn't find keyfile $currentfile for $1"
            return 1
        fi
    done
    return 0
}

# Helper function that sifts through /etc/nginx/conf.d/, looking for configs
# that don't have their keyfiles yet, and disabling them through renaming
auto_enable_configs() {
    for conf_file in /etc/nginx/conf.d/*.conf*; do
        if keyfiles_exist $conf_file; then
            if [ ${conf_file##*.} = nokey ]; then
                echo "Found all the keyfiles for $conf_file, enabling..."
                mv $conf_file ${conf_file%.*}
            fi
        else
            if [ ${conf_file##*.} = conf ]; then
                echo "Keyfile(s) missing for $conf_file, disabling..."
                mv $conf_file $conf_file.nokey
            fi
        fi
    done
}

# Helper function to ask certbot for the given domain(s).  Must have defined the
# EMAIL environment variable, to register the proper support email address.
get_certificate() {
    echo "Getting certificate for domain $1 on behalf of user $2"

    echo "running certbot ... $letsencrypt_url $1 $2"
    if [ "${DEBUG}" = "false" ]; then
        certbot certonly --agree-tos --webroot -w /data/www -d $1 --email $2 --keep --noninteractive --cert-name $1
    else
        certbot certonly --agree-tos --webroot -w /data/www -d $1 --staging --email $2 --debug --keep --noninteractive
    fi
}

# Given a domain name, return true if a renewal is required (last renewal
# ran over a week ago or never happened yet), otherwise return false.
is_renewal_required() {
    # If the file does not exist assume a renewal is required
    last_renewal_file="/etc/letsencrypt/live/$1/privkey.pem"
    [ ! -e "$last_renewal_file" ] && return;
    
    # If the file exists, check if the last renewal was more than a week ago
    one_week_sec=604800
    now_sec=$(date -d now +%s)
    last_renewal_sec=$(stat -c %Y "$last_renewal_file")
    last_renewal_delta_sec=$(( ($now_sec - $last_renewal_sec) ))
    is_finshed_week_sec=$(( ($one_week_sec - $last_renewal_delta_sec) ))
    [ $is_finshed_week_sec -lt 0 ]
}

# copies any *.conf files in /etc/nginx/user.conf.d
# to /etc/nginx/conf.d so they are included as configs
# this allows a user to easily mount their own configs
# We make use of `envsubst` to allow for on-the-fly templating
# of the user configs.
template_user_configs() {
    SOURCE_DIR="${1-/etc/nginx/user.conf.d}"
    TARGET_DIR="${2-/etc/nginx/conf.d}"

    # envsubst needs dollar signs in front of all variable names
    DENV=$(echo ${ENVSUBST_VARS} | sed -E 's/\$*([^ ]+)/\$$\1/g')

    echo "templating scripts from ${SOURCE_DIR} to ${TARGET_DIR}"
    echo "Substituting variables ${DENV}"

    if [ ! -d "$SOURCE_DIR" ]; then
        echo "no ${SOURCE_DIR}, nothing to do."
    else
        for conf in ${SOURCE_DIR}/*.conf; do
            envsubst "${DENV}" <"${conf}" > "${TARGET_DIR}/$(basename ${conf})"
        done
    fi
}

move_certificates() {
    # parse attributes
    domain=$1
    folder=/etc/letsencrypt/live
    echo "Checking generated certificates of ${domain}"

    # get folders
    dirs=($(ls $folder | grep ^$domain))
    for dir in ${dirs[*]}; do
        
        # move certificates to original and delete folder
        if [ $dir != $domain ]; then
            echo "Copying ${dir} to ${domain}"
            mkdir -p "$folder/$domain"
            cp -rf $folder/$dir/* $folder/$domain
            # rm -r $folder/$dir
        fi
    done
}

getCertbotEmail() {
    domain=$1

    # get certbot emails
    emails=$(echo $CERTBOT_EMAILS | tr "|" "\n")
    for email in $emails
    do
        # read second part of email
        IFS='@' read -ra emailInfo <<< "${email}"
        export EMAIL_DOMAIN=${emailInfo[1]}

        # check domain contains email domain
        if [[ $domain == *$EMAIL_DOMAIN* ]]; then
            certbotEmail=$email
            return
        fi
    done
    return
}