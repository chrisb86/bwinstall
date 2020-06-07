bwinstall installs and updates [bitwarden_rs](https://github.com/dani-garcia/bitwarden_rs) and the official bitwarden webvault on a FreeBSD system.
It takes care of installing the needed rust toolchain and an rc script to run bitwarden_rs as a service.

Just copy the script to a FreeBSD machine and run it. The magic will happen without user interaction. If an installation of _bitwarden_rs_ is found, it will update everything.

After installation check _/etc/rc.conf.d/bitwarden_ as this is the file to set all the configuration options. Check [.env.template](https://github.com/dani-garcia/bitwarden_rs/blob/master/.env.template) for a list of the possible settings.

This code is heavily inspired by the corresponding script from [JailManager](https://github.com/jailmanager/jailman/).
