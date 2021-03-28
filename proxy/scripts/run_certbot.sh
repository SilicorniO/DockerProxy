#!/bin/bash

# Source in util.sh so we can have our nice tools
. $(cd $(dirname $0); pwd)/util.sh

# We require an email to register the ssl certificate for
# if [ -z "$CERTBOT_EMAIL" ]; then
#     error "CERTBOT_EMAIL environment variable undefined; certbot will do nothing"
#     exit 1
# fi

exit_code=0
set -x
# Loop over every domain we can find
for domain in $(parse_domains); do
    if is_renewal_required $domain; then
        # Get certbot email
        getCertbotEmail $domain
        if [ $certbotEmail != "" ]; then
            echo "CertbotEmail for ${domain} is ${certbotEmail}"

            # Renewal required for this doman.
            # Last one happened over a week ago (or never)
            if ! get_certificate $domain $certbotEmail; then
                error "Cerbot failed for $domain. Check the logs for details."
                exit_code=1
            fi

            # Move certificates because certbot may hve been created a new folder
            move_certificates $domain
        else
            echo "Not run certbot for $domain; certbotEmail not found"
        fi

    else
        echo "Not run certbot for $domain; last renewal happened just recently."
    fi
done

# After trying to get all our certificates, auto enable any configs that we
# did indeed get certificates for
auto_enable_configs

set +x
exit $exit_code