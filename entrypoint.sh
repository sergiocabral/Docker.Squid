#!/bin/bash

function create_dir {
    local VAR=$1;
    local DIR=${!VAR};
    printf "Configuring directory: $VAR\n";
    mkdir -p $DIR;
    chmod -R 755 $DIR;
    chown -R squid:squid $DIR;
    ls -ld $(realpath $DIR);
}

set -e;

printf "Entrypoint for docker image: squid\n";

ARGS="$*";

SUFFIX_TEMPLATE="template";

FILE_SQUID=$(which squid || echo "");
FILE_CONF="squid.conf";
FILE_CONF_BACKUP="$FILE_CONF.original";

DIR_SCRIPTS="/root";
DIR_CONF="/etc/squid";
DIR_CONF_FINAL="$DIR_CONF/conf";
DIR_CONF_TEMPLATES="$DIR_CONF/conf.templates";
DIR_PASSWD="$DIR_CONF/passwd";
DIR_LOG="/var/log/squid";

if [ ! -e "$FILE_SQUID" ];
then
    printf "Squid is not installed.\n" >> /dev/stderr;
    exit 1;
fi

IS_FIRST_CONFIGURATION=$((test ! -e $DIR_CONF/$FILE_CONF_BACKUP && echo true) || echo false);

if [ $IS_FIRST_CONFIGURATION = true ];
then
    printf "This is the FIRST RUN.\n";
else
    printf "This is NOT the first run.\n";
fi

create_dir DIR_CONF;
create_dir DIR_CONF_FINAL;
create_dir DIR_CONF_TEMPLATES;
create_dir DIR_PASSWD;
create_dir DIR_LOG;

printf "Deleting previous authentication data.\n";
rm -f $DIR_PASSWD/passwd;

if [ -z $SQUID_USERS ];
then
    printf "No users was found in environment variable SQUID_USERS.\n";
else
    printf "Users data found in environment variable SQUID_USERS.\n";

    touch $DIR_PASSWD/passwd;

    readarray -t AUTH_LIST < <($DIR_SCRIPTS/split-to-lines.sh "," $SQUID_USERS);    
    for AUTH in ${AUTH_LIST[@]};
    do
        readarray -t USER_PASS < <($DIR_SCRIPTS/split-to-lines.sh "=" $AUTH);

        USER=${USER_PASS[0]};
        PASS=${USER_PASS[1]};

        htpasswd -b $DIR_PASSWD/passwd "$USER" "$PASS";
    done

    printf "The authentication data was saved.\n";
    ls -l $DIR_PASSWD/passwd;
fi

if [ $IS_FIRST_CONFIGURATION = true ];
then
    printf "Backing up the configuration file.\n";
    mv $DIR_CONF/$FILE_CONF $DIR_CONF/$FILE_CONF_BACKUP;
    ls -l $DIR_CONF/$FILE_CONF_BACKUP;
fi

if [ ! -e "$DIR_CONF_TEMPLATES/$FILE_CONF.$SUFFIX_TEMPLATE" ];
then
    printf "Creating the default template configuration file.\n";
    cp $DIR_CONF/$FILE_CONF_BACKUP $DIR_CONF_TEMPLATES/$FILE_CONF.$SUFFIX_TEMPLATE;
    ls -l $DIR_CONF_TEMPLATES/$FILE_CONF.$SUFFIX_TEMPLATE;
fi

$DIR_SCRIPTS/envsubst-file.sh "$DIR_CONF_TEMPLATES/$FILE_CONF.$SUFFIX_TEMPLATE" "$DIR_CONF_FINAL/$FILE_CONF";

printf "Starting squid.\n";

$FILE_SQUID -f $DIR_CONF_FINAL/$FILE_CONF -NYCd 1 ${ARGS};
