# Docker.Squid

Proxy server using the Squid application.

## Configuration

It is possible to configure user-based access and password based on the environment variable.

Or you can ignore environment variables and use the specific setting in the `squid.conf` file.

## Environment Variables

`SQUID_USERS` = `username1=password1,username2=password2,username3=password3`

 - Enter username and password in this format to create credentials for accessing the proxy.

`SQUID_LOGIN_MESSAGE` = `Your Login Message Here`

- Message (realm) displayed during the login process.

`SQUID_ALLOW_UNSECURE` = `true`

- Only `true` value is possible. Sinalize that you allow access to unusual ports.
- When not informed, or have another value, allows access only to safe ports:
	- 21, ftp
	- 70, gopher
	- 80, http
	- 210, wais
	- 280, http-mgmt
	- 443, https
	- 488, gss-http
	- 591, filemaker
	- 777, multiling http
	- 1025-65535, unregistered ports


## Suggested Directory Volumes

`/etc/squid.templates`

- Use files `/etc/squid.templates/*.template` to make the files in the `/etc/squid.conf` directory with replacement of environment variables with their values.

`/etc/squid.conf`

- Configuration directory used by the Squid application. All configuration files are here.

`/var/log/squid`

- Log files.

## Exposed Port

The default working port for Squid is 3128. But can be modified in the `squid.conf` file.
