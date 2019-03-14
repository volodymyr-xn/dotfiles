/usr/bin - for software installed by package manager (apt, yum, pac, dnf)
/usr/local/bin - for software manually compiled and installed

## What --prefix Means
When you run ./configure --prefix=directory, you are indicating that the software should be installed under the  directory directory. But this rarely, if ever, places loose files in directory. Instead, it places files that serve different purposes in the different subdirectories of directory. If those subdirectories don't exist, it creates them.

Executables usually go in directory/bin, though they may go in directory/sbin if they're commonly used for system administration or they may go (more rarely, these days) in directory/games if they are games. Libraries go in  directory/lib or another similarly named directory like  directory/lib32. Header files go in  directory/include. Manual pages go in directory/man. Data files used by the software go in  directory/share.

That's what it means for directory to be a prefix. It's the parent directory that contains the locations in which different files will be installed. It thus appears as a prefix in the absolute paths of most files and directories created by running make install or sudo make install.

There are some exceptions to this. Systemwide configuration files--which are sometimes created when installing the software that will use them, though not always--usually go in /etc. This is not typically affected by specifying a different prefix. Even if you install a lot of software in /usr/local, it will still mostly use  /etc, and your /usr/local/etc directory will probably be nonexistent, empty, or contain very few files.

On many systems, you can find more information about typical filesystem layout by running man hier. If you're using a GNU/Linux system you may be interested in the Filesystem Hierarchy Standard.


