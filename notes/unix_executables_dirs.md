/bin (and /sbin) were intended for programs that needed to be on a small / partition before the larger /usr, etc. partitions were mounted. These days, it mostly serves as a standard location for key programs like /bin/sh, although the original intent may still be relevant for e.g. installations on small embedded devices.

/sbin, as distinct from /bin, is for system management programs (not normally used by ordinary users) needed before /usr is mounted.

/usr/bin is for distribution-managed normal user programs.

There is a /usr/sbin with the same relationship to /usr/bin as /sbin has to /bin.

/usr/local/bin is for normal user programs not managed by the distribution package manager, e.g. locally compiled packages. You should not install them into /usr/bin because future distribution upgrades may modify or delete them without warning.

/usr/local/sbin, as you can probably guess at this point, is to /usr/local/bin as /usr/sbin to /usr/bin.


/usr/bin - for software installed by package manager (apt, yum, pac, dnf)
/usr/local/bin - for software manually compiled and installed

