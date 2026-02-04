# Comprehensive Guide to Linux Filesystem Paths, Uses, and Best Practices

## Overview

Linux filesystems adhere to the Filesystem Hierarchy Standard (FHS), which organizes the structure, content, and mounting points of files and directories. Understanding these is critical for system administration, security, performance, and application deployment[1][2][3].

## Top-Level Directory Structure

| Directory | Description and Use |
|-----------|--------------------|
| `/`       | The root — the base of the filesystem. All files and directories branch from here. Only root can write in this directory[1][4]. |
| `/bin`    | Essential user command binaries (e.g., ls, cp, mv) needed for single-user mode and all users[4][2]. |
| `/boot`   | Kernel, bootloader, and system startup files. Only root should modify[1][4]. |
| `/dev`    | Device nodes representing hardware (e.g., `/dev/sda`, `/dev/null`)[4]. |
| `/etc`    | System configuration files, startup scripts. Only text-based configs; binaries not allowed[1][4]. |
| `/home`   | User directories (e.g., `/home/alice`). User files, settings, and personal data[4][5]. |
| `/lib`    | Libraries for binaries in `/bin` and `/sbin`. Also contains modules[4][2]. |
| `/media`  | Mount point for removable media (USB drives, CDs)[4][5]. |
| `/mnt`    | Temp mount point for additional filesystems/disks[4][5]. |
| `/opt`    | Third-party add-on applications and packages[4]. |
| `/proc`   | Virtual filesystem providing process and kernel information[4]. |
| `/root`   | Root user's home directory[4][5]. |
| `/run`    | Runtime variable data since last boot (e.g., PID files)[4]. |
| `/sbin`   | System binaries for administration (fsck, reboot). Usually for root or sudoers[4]. |
| `/srv`    | Data for services provided by the system (HTTP, FTP)[4]. |
| `/tmp`    | Temporary files. Typically world-writable but may be purged on reboot[4]. |
| `/usr`    | User programs, libraries, documentation; secondary hierarchy[4][2]. |
| `/var`    | Variable files: logs, caches, mail, spoolers[4]. |
| `/sys`    | Virtual filesystem exposing kernel devices and settings (sysfs)[2]. |

## Understanding Absolute vs. Relative Paths

- **Absolute Path**: Starts from the root. E.g., `/usr/share/doc`.
- **Relative Path**: Relative to your current directory. E.g., `docs/notes.txt` from `/home/alice` refers to `/home/alice/docs/notes.txt`[6][7].

Best practice: Use absolute paths in scripts for reliability; use relative paths interactively for convenience[6][7].

## Key Subdirectories and Their Uses

### /etc – System Configurations

- Stores text-based config files for binaries, services, and network settings.
- Never place user scripts or binaries here.
- Backup regularly and use version control (e.g., etckeeper).

### /var – Variable State

- Holds logs (`/var/log`), email (`/var/mail`), spool directories, temporary servlet or cache data.
- Monitor `/var` disk usage — running out of space can disrupt services.

### /usr – User Programs and Data

- `/usr/bin`, `/usr/sbin`: Non-critical user and administrative tools.
- `/usr/local`: Site-specific software compiled or installed by the admin.

Best practice: Custom software for just this system should go under `/usr/local`, never overwrite packaged software in `/usr`.

### /tmp and /var/tmp – Temporary Files

- `/tmp` is for files needed only until next reboot.
- `/var/tmp` persists files between reboots.

Security tip: Both are world-writable — use `noexec`, `nodev`, and `nosuid` mount options[8].

## Mount Points and Partitions

- **/mnt** and **/media** used for mounting external filesystems.
- Use `mount` and `/etc/fstab` for stable, repeatable mounting.
- Consider separate partitions for `/home`, `/var`, `/tmp` for better data management and isolation[8].

Partitioning tips:
- Mount `/tmp`, `/var/tmp` with the `noexec`, `nosuid`, and `nodev` flags.
- Consider quotas on `/home` to prevent a single user from exhausting disk space[8].

## File Permissions and Ownership

- Use the principle of least privilege: restrict write/execute permissions where possible.
- Use `chmod`, `chown`, and `umask` to control access.
- Safeguard sensitive files (e.g., private SSH keys) with restrictive permissions (e.g., `chmod 600`).

Auditing tip: Regularly check permissions and run `find / -perm -o+w` to detect world-writable files[8].

## PATH Variable and Binary Locations

- PATH defines the directories searched for commands.
- Typical order: `/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin`.
- Place custom or site-specific scripts in `/usr/local/bin` or `~/bin`[5].

Best practice: Avoid cluttering `/bin` and `/usr/bin` with custom scripts. Use `/usr/local/bin` for admin-installed scripts, and `~/bin` for individual user scripts.

## Filesystem Hierarchy Best Practices

- **Follow FHS**: Adhere to the FHS for compatibility across distributions and automation tools[1][2][3].
- **Least Privilege**: Assign minimal permissions, particularly for sensitive files and directories[8].
- **Back Up /etc, /home, /var**: These hold your config, user data, and logs.
- **Symlinks and Consolidation Trends**: Some distros now symlink `/bin` to `/usr/bin`, `/lib` to `/usr/lib` for simplification. Know your distro’s policy and adapt scripts accordingly[2].
- **Maintain Clean `/tmp` and `/var/tmp`**: Prevent attacks by regularly cleaning temp directories and using proper mount options[8].
- **Monitor Disk Usage**: Use tools like `df`, `du`, `ncdu` to watch space, especially in `/var`, `/tmp`, `/home`.
- **Organize Application Data**: Store apps with large data needs in dedicated mount points.
- **Avoid Hard-coding Paths**: Write scripts using variables or config files, avoid fixed assumptions about file locations.

## Directory Structure Table (Summary)

| Directory        | Function and Best Practice Example |
|------------------|-----------------------------------|
| `/`              | System root. Modify only as root[1][4]. |
| `/home`          | User data. Use quotas, backup regularly[5]. |
| `/etc`           | Config files. Protect by restricting write access. Use version control. |
| `/var/log`       | Logging. Monitor size and rotate logs. |
| `/tmp`, `/var/tmp` | Temp files. Use security-minded mount options; purge appropriately[8]. |
| `/usr/local`     | Local software. Keep separate from system package manager[4][2]. |
| `/opt`           | Third-party large applications. Unpack major software here. |
| `/srv`           | Service data (web/ftp). Ideal for collected data. |

## Advanced Topics

### Filesystem Security

- Store sensitive data in user home directories or root-owned directories with minimal permissions.
- Use mandatory access control systems (SELinux, AppArmor) for greater security constraints.

### Filesystem Maintenance

- Run regular filesystem checks (e.g., `fsck` on boot for ext* filesystems).
- Monitor for inode exhaustion as well as disk fullness.
- Use journaling filesystems (e.g., ext4, XFS) for resilience.

### Adapting to Modern Trends

- Be aware of virtualization: `/proc`, `/sys` are virtual and provide dynamic runtime data.
- Watch for distribution-specific structures (snap, flatpak create their own directories under `/var/lib`, `/snap`, `/run/user`, etc.)

## References

Inline citations have been included throughout for further reading and verification. This guide draws on FHS 3.0, major Linux administration guides, and security best practices[1][8][4][6][2][5][3][7].

[1] https://www.geeksforgeeks.org/linux-file-hierarchy-structure/
[2] https://en.wikipedia.org/wiki/Filesystem_Hierarchy_Standard
[3] https://refspecs.linuxfoundation.org/FHS_3.0/fhs/index.html
[4] https://linuxjourney.com/lesson/filesystem-hierarchy
[5] https://blog.ronin.cloud/linux-directories-paths/
[6] https://pressbooks.senecapolytechnic.ca/uli101/chapter/file-paths-in-linux/
[7] https://www.redhat.com/en/blog/navigating-linux-filesystem
[8] https://dev.to/lakmalya/securing-linux-filesystems-best-practices-for-devops-security-2860
[9] https://www.interserver.net/tips/kb/linux-file-system-and-file-paths/
[10] https://labex.io/questions/what-is-the-purpose-of-directory-structure-in-linux-271330
[11] https://gorbe.io/posts/linux/filesystem-hierarchy/
[12] https://www.reddit.com/r/linux/comments/qkm01c/a_refresher_on_the_linux_file_system_structure/
[13] https://www.geeksforgeeks.org/linux-directory-structure/
[14] https://refspecs.linuxfoundation.org/FHS_3.0/index.html
[15] https://systemdesignschool.io/blog/linux-file-systems
[16] https://linuxhandbook.com/linux-directory-structure/
[17] https://www.lenovo.com/us/en/glossary/fhs/
[18] https://documentation.commvault.com/11.20/best_practices_linux_file_system.html
[19] https://hpc.nmsu.edu/onboarding/linux/files-folders/
[20] https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/5/html/deployment_guide/s1-filesystem-fhs