#!/bin/bash

set -e;

printf "                                                     .                  \n";
printf "   ___      _                                       ":"                 \n";
printf "  / __\__ _| |__  _ __ ___  _ __   ___  ___       ___:____     |"\/"|   \n";
printf " / /  / _' | '_ \| '__/ _ \| '_ \ / _ \/ __|    ,'        '.    \  /    \n";
printf "/ /__| (_| | |_) | | | (_) | | | |  __/\__ \    |  O        \___/  |    \n";
printf "\____/\__,_|_.__/|_|  \___/|_| |_|\___||___/  ~^~^~^~^~^~^~^~^~^~^~^~^~ \n";
printf "       __             _     _                                           \n";
printf "      / _\ __ _ _   _(_) __| |                                          \n";
printf "      \ \ / _' | | | | |/ _' |            https://github.com            \n";
printf "      _\ \ (_| | |_| | | (_| |                  /sergiocabral           \n";
printf "      \__/\__, |\__,_|_|\__,_|                 /Docker.Squid            \n";
printf "             |_|                                                        \n";
printf "\n";

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
DIR_CONF_DOCKER="$DIR_CONF.conf";
DIR_SCRIPTS="${DIR_SCRIPTS:-/root}";
LS="ls --color=auto -CFl";

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

    USER=squid;
    DIR_LOG="/var/log/squid";        
    chmod -R 755 $DIR_LOG && chown -R $USER:$USER $DIR_LOG;

    $SQUID_EXECUTABLE -Nz;

    printf "Configuring directories.\n";

    cp -R $DIR_CONF $DIR_CONF_BACKUP;
    cp -R $DIR_CONF/* $DIR_CONF_DOCKER/;
    rm -R $DIR_CONF;
    ln -s $DIR_CONF_DOCKER $DIR_CONF;

    mkdir -p $DIR_CONF_TEMPLATES;

    if [ -d "$DIR_CONF_TEMPLATES" ] && [ ! -z "$(ls -A $DIR_CONF_TEMPLATES)" ];
    then
        printf "Warning: The $DIR_CONF_TEMPLATES directory already existed and will not have its content overwritten.\n";
    else
        printf "Creating file templates in $DIR_CONF_TEMPLATES\n";

        cp    $DIR_CONF/*.conf $DIR_CONF_TEMPLATES;
        cp    $DIR_CONF/*.css  $DIR_CONF_TEMPLATES;
        ls -1 $DIR_CONF_TEMPLATES | \
           grep -v $SUFFIX_TEMPLATE | \
           xargs -I {} mv $DIR_CONF_TEMPLATES/{} $DIR_CONF_TEMPLATES/{}$SUFFIX_TEMPLATE;    
    fi
    $LS -Ad $DIR_CONF_TEMPLATES/*;

    printf "Configured directories:\n";

    chmod -R 755 $DIR_LOG               && chown -R $USER:$USER $DIR_LOG;
    chmod -R 755 $DIR_CONF_BACKUP       && chown -R $USER:$USER $DIR_CONF_BACKUP;
    chmod -R 755 $DIR_CONF_TEMPLATES    && chown -R $USER:$USER $DIR_CONF_TEMPLATES;
    chmod -R 755 $DIR_CONF_DOCKER       && chown -R $USER:$USER $DIR_CONF_DOCKER;
    
    $LS -d $DIR_CONF $DIR_CONF_BACKUP $DIR_CONF_TEMPLATES $DIR_CONF_DOCKER;
else
    printf "This is NOT the first run.\n";
fi

printf "Tip: Use files $DIR_CONF_TEMPLATES/*$SUFFIX_TEMPLATE to make the files in the $DIR_CONF directory with replacement of environment variables with their values.\n";

printf "Deleting previous authentication file $DIR_CONF/passwd\n";
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

        echo $PASS | htpasswd -i $DIR_CONF_DOCKER/passwd $USER;
    done

    printf "The authentication data was saved to $DIR_CONF/passwd\n";
fi

$DIR_SCRIPTS/envsubst-files.sh "$SUFFIX_TEMPLATE" "$DIR_CONF_TEMPLATES" "$DIR_CONF";

# More details for squid.conf: http://www.squid-cache.org/Doc/config/auth_param/
FILE_CONF="$DIR_CONF/squid.conf";
FILE_CONF_TEMP="/tmp/squid.conf";
COMMENT_DISABLED="#[disabled]";

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
    sed -i -e s/"http_access deny !Safe_ports"/"$COMMENT_DISABLED http_access deny !Safe_ports"/ $FILE_CONF;
    sed -i -e s/"http_access deny CONNECT !SSL_ports"/"$COMMENT_DISABLED http_access deny CONNECT !SSL_ports"/ $FILE_CONF;

    echo "http_access allow !Safe_ports" >> $FILE_CONF_TEMP;
    echo "http_access allow CONNECT !SSL_ports" >> $FILE_CONF_TEMP;
fi

if [ -e "$FILE_CONF_TEMP" ];
then
    sed -i -e s/"http_access deny all"/"$COMMENT_DISABLED http_access deny all"/ $FILE_CONF;
    echo "http_access deny all" >> $FILE_CONF_TEMP;

    printf "Appended to the configuration file at $FILE_CONF\n";
    printf "\n";
    cat $FILE_CONF_TEMP | xargs -I {} echo "    " {};
    printf "\n";

    echo "" >> $FILE_CONF;
    echo "# The settings below have been added based on" >> $FILE_CONF;
    echo "# values received from the environment variables." >> $FILE_CONF;
    echo "# Some settings above have been commented with '$COMMENT_DISABLED'." >> $FILE_CONF;
    echo "" >> $FILE_CONF;
    cat $FILE_CONF_TEMP >> $FILE_CONF;
    rm $FILE_CONF_TEMP;
fi

printf "Starting squid.\n";

$SQUID_EXECUTABLE -NYCd 1 ${SQUID_ARGS};
