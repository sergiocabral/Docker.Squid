#!/bin/bash

set -e;

printf "Entrypoint for docker image: squid\n";

SQUID_ARGS="$* $SQUID_ARGS";
EXEC_SQUID=$(which squid || echo "");
SUFFIX_TEMPLATE="${SUFFIX_TEMPLATE:-.template}";
DIR_SCRIPTS="${DIR_SCRIPTS:-/root}";
DIR_CONF="${DIR_CONF:-/etc/squid}";
DIR_CONF_BACKUP="$DIR_CONF.original";
DIR_CONF_TEMPLATES="$DIR_CONF.templates";
DIR_CONF_DOCKER="$DIR_CONF.docker";

if [ ! -e "$EXEC_SQUID" ];
then
    printf "Squid is not installed.\n" >> /dev/stderr;
    exit 1;
fi

IS_FIRST_CONFIGURATION=$((test ! -d $DIR_CONF_BACKUP && echo true) || echo false);

if [ $IS_FIRST_CONFIGURATION = true ];
then
    printf "This is the FIRST RUN.\n";
    
    printf "Running squid for the first time.\n";

    $EXEC_SQUID -Nz;

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

printf "Deleting previous authentication data.\n";
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

printf "Starting squid.\n";

$EXEC_SQUID -NYCd 1 ${SQUID_ARGS};
