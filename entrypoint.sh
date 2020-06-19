#!/bin/bash

set -e;

printf "Entrypoint for docker image: squid\n";

# Variables to configure externally.
SQUID_ARGS="$* $SQUID_ARGS";
SQUID_LOGIN_MESSAGE="${SQUID_LOGIN_MESSAGE:-Squid proxy-caching web server}";
SQUID_CREDENTIALS_TTL="${SQUID_CREDENTIALS_TTL:-2 hours}";
SQUID_CHILDREN="${SQUID_CHILDREN:-5 startup=5 idle=1}";
SQUID_ALLOW_UNSECURE="${SQUID_ALLOW_UNSECURE:-}";

SQUID_EXECUTABLE=$(which squid || echo "");
SUFFIX_TEMPLATE=".template";
DIR_CONF="/etc/squid";
DIR_CONF_BACKUP="$DIR_CONF.original";
DIR_CONF_TEMPLATES="$DIR_CONF.templates";
DIR_CONF_DOCKER="$DIR_CONF.docker";
DIR_SCRIPTS="${DIR_SCRIPTS:-/root}";

if [ ! -e "$SQUID_EXECUTABLE" ];
then
    printf "Squid is not installed.\n" >> /dev/stderr;
    exit 1;
fi

IS_FIRST_CONFIGURATION=$((test ! -d $DIR_CONF_BACKUP && echo true) || echo false);

if [ $IS_FIRST_CONFIGURATION = true ];
then
    printf "This is the FIRST RUN.\n";
    
    printf "Running squid for the first time.\n";

    $SQUID_EXECUTABLE -Nz;

    printf "Creating directories.\n";

    cp -R $DIR_CONF $DIR_CONF_BACKUP;
    mv    $DIR_CONF $DIR_CONF_DOCKER;
    ln -s $DIR_CONF_DOCKER $DIR_CONF;
    mkdir $DIR_CONF_TEMPLATES;
    cp    $DIR_CONF/*.conf $DIR_CONF_TEMPLATES;
    cp    $DIR_CONF/*.css  $DIR_CONF_TEMPLATES;
    ls -1 $DIR_CONF_TEMPLATES | xargs -I {} mv $DIR_CONF_TEMPLATES/{} $DIR_CONF_TEMPLATES/{}$SUFFIX_TEMPLATE;
    
    ls --color=auto -CFla -d $DIR_CONF $DIR_CONF_BACKUP $DIR_CONF_TEMPLATES $DIR_CONF_DOCKER;
else
    printf "This is NOT the first run.\n";
fi

printf "Tip: Use files $DIR_CONF_TEMPLATES/*$SUFFIX_TEMPLATE to make the files in the $DIR_CONF directory with replacement of environment variables with their values.\n";

printf "Deleting previous authentication file $DIR_CONF/passwd.\n";
rm -f $DIR_CONF/passwd;

if [ -z $SQUID_USERS ];
then
    printf "No users was found in environment variable SQUID_USERS.\n";
else
    printf "Users data found in environment variable SQUID_USERS.\n";

    touch $DIR_CONF/passwd;

    readarray -t AUTH_LIST < <($DIR_SCRIPTS/split-to-lines.sh "," $SQUID_USERS);    
    for AUTH in ${AUTH_LIST[@]};
    do
        readarray -t USER_PASS < <($DIR_SCRIPTS/split-to-lines.sh "=" $AUTH);

        USER=${USER_PASS[0]};
        PASS=${USER_PASS[1]};

        htpasswd -b $DIR_CONF/passwd "$USER" "$PASS";
    done

    printf "The authentication data was saved to $DIR_CONF/passwd.\n";

fi

$DIR_SCRIPTS/envsubst-files.sh "$SUFFIX_TEMPLATE" "$DIR_CONF_TEMPLATES" "$DIR_CONF";

# More details for squid.conf: http://www.squid-cache.org/Doc/config/auth_param/
FILE_CONF="$DIR_CONF/squid.conf";
FILE_CONF_TEMP="/tmp/squid.conf";

rm -f $FILE_CONF_TEMP;

if [ -e "$DIR_CONF/passwd" ];
then
    echo "auth_param basic program /usr/lib/squid/basic_ncsa_auth $DIR_CONF/passwd" >> $FILE_CONF_TEMP;
    echo "auth_param basic children $SQUID_CHILDREN" >> $FILE_CONF_TEMP;
    echo "auth_param basic credentialsttl $SQUID_CREDENTIALS_TTL" >> $FILE_CONF_TEMP;
    echo "auth_param basic realm $SQUID_LOGIN_MESSAGE" >> $FILE_CONF_TEMP;
    echo "acl password proxy_auth REQUIRED" >> $FILE_CONF_TEMP;
    echo "http_access allow password" >> $FILE_CONF_TEMP;
fi

if [ "$SQUID_ALLOW_UNSECURE" = true ];
then
    echo "http_access allow !Safe_ports" >> $FILE_CONF_TEMP;
    echo "http_access allow CONNECT !SSL_ports" >> $FILE_CONF_TEMP;
fi

if [ "$SQUID_ALLOW_UNSECURE" = false ];
then
    echo "http_access deny !Safe_ports" >> $FILE_CONF_TEMP;
    echo "http_access deny CONNECT !SSL_ports" >> $FILE_CONF_TEMP;
fi

if [ -e "$FILE_CONF_TEMP" ];
then
    printf "Appeding above settings to $FILE_CONF:\n";
    printf "\n";
    cat $FILE_CONF_TEMP | xargs -I {} echo "    " {};
    printf "\n";

    echo "" >> $FILE_CONF;
    cat $FILE_CONF_TEMP >> $FILE_CONF;
    echo "" >> $FILE_CONF;
fi

printf "Starting squid.\n";

$SQUID_EXECUTABLE -NYCd 1 ${SQUID_ARGS};
