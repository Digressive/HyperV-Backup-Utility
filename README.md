# Hyper-V Backup Utility

## Flexible Hyper-V Backup Utility

For full change log and more information, [visit my site.](https://gal.vin/utils/hyperv-backup-utility/)

Hyper-V Backup Utility is available from:

* [GitHub](https://github.com/Digressive/HyperV-Backup-Utility)
* [The Microsoft PowerShell Gallery](https://www.powershellgallery.com/packages/Hyper-V-Backup)

Please consider supporting my work:

* Support with a one-time donation using [PayPal](https://www.paypal.me/digressive).

Please report any problems via the ‘issues’ tab on GitHub.

-Mike

## Features and Requirements

* Designed to be run on a Hyper-V host.
* The Hyper-V host must have the Hyper-V management PowerShell modules installed.
* Can be used to backup VMs to a device which the Hyper-V host does not have permission to run a regular export to.
* Supports Hyper-V hosts in a clustered configuration.
* The utility requires at least Windows PowerShell 5.0.
* Tested on Windows 11, Windows 10, Windows Server 2022, Windows Server 2019 and Windows Server 2016.
* The backup log can be sent via email and/or webhook.

## 7-Zip support

I've implemented support for 7-Zip into the script. You should be able to use any option that 7-zip supports, although currently the only options I've tested fully are '-t' archive type, '-p' password and '-v' split files.

## When to use the -NoPerms switch

The -NoPerms switch is intended as a workaround when used in an environment where the Hyper-V host cannot be given the required permissions to run a regular export to a remote device such as a NAS device.

Hyper-V’s export operation requires that the computer account in Active Directory have access to the location where the exports are being stored. I recommend creating an Active Directory group for the Hyper-V hosts and then giving the group the required ‘Full Control’ file and share permissions.

When a NAS, such as a QNAP device is intended to be used as an export location, Hyper-V will not be able to complete the operation as the computer account will not have access to the share on the NAS. To copy all the files necessary for a complete backup, the VM must be in an offline state for the operation to be completed. Due to this the script will put the VM in a 'Saved' state so the files can be copied. Previously the VM would be shutdown but this is a faster and safer method as the VM does not require any integrations to be put in a saved state.

## Generating A Password File For SMTP Authentication

The password used for SMTP server authentication must be in an encrypted text file. To generate the password file, run the following command in PowerShell on the computer and logged in with the user that will be running the utility. When you run the command, you will be prompted for a username and password. Enter the username and password you want to use to authenticate to your SMTP server.

Please note: This is only required if you need to authenticate to the SMTP server when send the log via e-mail.

``` powershell
$creds = Get-Credential
$creds.Password | ConvertFrom-SecureString | Set-Content c:\scripts\ps-script-pwd.txt
```

After running the commands, you will have a text file containing the encrypted password. When configuring the -Pwd switch enter the path and file name of this file.

## Restoring a Virtual Machine

The easiest and quickest way to restore a Virtual Machine that has been backed up using this script is to use Hyper-V's native import function.

1. Copy the backup of the VM you want to restore to a location on the VM host server that the VM should run from. If the backup is compressed, uncompress the file.
2. In the Hyper-V Manager, right-click on the VM host and select 'Import Virtual Machine'.
3. Browse to the location of the VM backup folder and click Next.
4. Select the VM you want to restore.
5. Select 'Register the virtual machine in-place' option.
6. The VM will be registered in Hyper-V and available for use.

## Configuration

Here’s a list of all the command line switches and example configurations.

| Command Line Switch | Description | Example |
| ------------------- | ----------- | ------- |
| -BackupTo | The path the virtual machines should be backed up to. Each VM will have its own folder inside this location. | [path\] |
| -List | Enter the path to a txt file with a list of Hyper-V VM names to backup. If this option is not configured, all running VMs will be backed up. | [path\]vms.txt |
| -Wd | The path to the working directory to use for the backup before copying it to the final backup directory. Use a directory on local fast media to improve performance. | [path\] |
| -NoPerms | Configures the utility to shut down running VMs to do the file-copy based backup instead of using the Hyper-V export function. If no list is specified and multiple VMs are running, the process will run through the VMs alphabetically. | N/A |
| -Keep | Instructs the utility to keep a specified number of days worth of backups. VM backups older than the number of days specified will be deleted. | [number] |
| -Compress | This option will create a zip file of each Hyper-V VM backup. | N/A |
| -Sz | Configure the utility to use 7-Zip to compress the VM backups. 7-Zip must be installed in the default location ```$env:ProgramFiles``` if it is not found, Windows compression will be used. | N/A |
| -SzOptions | Use this switch to configure options for 7-Zip. The switches must be comma separated. | "'-t7z,-v2G,-ppassword'" |
| -ShortDate | Configure the script to use only the Year, Month and Day in backup filenames. | N/A |
| -LowDisk | Remove old backups before new ones are created. For low disk space situations. | N/A |
| -L | The path to output the log file to. | [path\] |
| -LogRotate | Remove logs produced by the utility older than X days | [number] |
| -NoBanner | Use this option to hide the ASCII art title in the console. | N/A |
| -Help | Display usage information. No arguments also displays help. | N/A |
| -ProgCheck | Send notifications (email or webhook) after each VM is backed up. | N/A |
| -OptimiseVHD | Optimise the VHDs and make them smaller before copy. Must be used with -NoPerms option. | N/A |
| -Webhook | The txt file containing the URI for a webhook to send the log file to. | [path\]webhook.txt |
| -Subject | Specify a subject line. If you leave this blank the default subject will be used | "'[Server: Notification]'" |
| -SendTo | The e-mail address the log should be sent to. For multiple address, separate with a comma. | [example@contoso.com] |
| -From | The e-mail address the log should be sent from. | [example@contoso.com] |
| -Smtp | The DNS name or IP address of the SMTP server. | [smtp server address] |
| -Port | The Port that should be used for the SMTP server. If none is specified then the default of 25 will be used. | [port number] |
| -User | The user account to authenticate to the SMTP server. | [example@contoso.com] |
| -Pwd | The txt file containing the encrypted password for SMTP authentication. | [path\]ps-script-pwd.txt |
| -UseSsl | Configures the utility to connect to the SMTP server using SSL. | N/A |

## How to use

``` txt
[path\]Hyper-V-Backup.ps1 -BackupTo [path\]
```

This will backup all the VMs running to the backup location specified.

## Change Log

### 2024-03-18: Version 24.03.18

* Added fix for verifying password protected 7-Zip archives from [Issue 33](https://github.com/Digressive/HyperV-Backup-Utility/issues/33)

### 2024-03-08: Version 24.03.08

* Fixed 7-Zip split files getting renamed and not keeping file extensions when short dates are used.
* Added a verify operation for 7-Zip created archives as per [Issue 33](https://github.com/Digressive/HyperV-Backup-Utility/issues/33)
* Fixed an issue where failed backups where also listed as successful.
* Overhauled the backup success/fail checks. They now work a lot more reliably.
* Added check for the work dir/backup dir to exist before trying to remove as this caused a script error.
* Cleaned up console and log file output.

### 2023-09-05: Version 23.09.05

* Added new features from [Issue 28](https://github.com/Digressive/HyperV-Backup-Utility/issues/28)
* Added -ProgCheck option. With this option set, notifications will be sent after each VM is backup is finished.
* Added backup time duration to the script output.
* Added -OptimiseVHD option to shrink the size of the VHDs. Can only be used the the -NoPerms option as the VM must be offline to optimise the VHDs.

### 2023-04-28: Version 23.04.28

* Minor improvement to update checker. If the internet is not reachable it silently errors out.

### 2023-02-18: Version 23.02.18

* Removed specific SMTP config info from config report. [Issue 24](https://github.com/Digressive/HyperV-Backup-Utility/issues/24)
* Added a "simple auth edition" version of the script. [Issue 25](https://github.com/Digressive/HyperV-Backup-Utility/issues/25)

### 2023-02-07: Version 23.02.07

* Removed SMTP authentication details from the 'Config' report. Now it just shows as 'configured' if SMTP user is configured. To be clear: no passwords were ever shown or stored in plain text.

### 2023-01-09: Version 23.01.09

* Added script update checker - shows if an update is available in the log and console.
* Added VM restore instructions to readme.md.
* Added "low disk space" mode. -LowDisk switch deletes previous backup files and folders before backup for systems with low disk space.
* Added webhook option to send log file to.
* Lot's of refactored code using functions. Simpler, easier to manage. Long overdue.
* Fixed bug that started VMs that were shutdown.
* Changed "VM not running" from an error state to an informational state.
* Changed "Backup Success" to a success state (green text in console).
* Changed -NoPerms so that VMs are now saved instead of shutdown (safer, faster, does not require Hyper-V integrations)

### 2022-06-22: Version 22.06.22

* Fixed an issue with the code checking for OS version too late.

### 2022-06-18: Version 22.06.18

* Fixed Get-Service check outputting to console.
* Fixed backup success/fail counter not working with -NoPerms switch.

### 2022-06-17: Version 22.06.17

* Fixed an issue with Windows Server 2012 R2 when checking for the Hyper-V service to be installed and running.

### 2022-06-14: Version 22.06.11

* Fixed [Issue 19 on GitHub](https://github.com/Digressive/HyperV-Backup-Utility/issues/19) - All Virtual Hard Disk folders should now be called "Virtual Hard Disks" and not some with the name "VHD".
* Fixed [Issue 20 on GitHub](https://github.com/Digressive/HyperV-Backup-Utility/issues/20) - If -L [path\] not configured then a non fatal error would occur as no log path was specified for the log to be output to.
* Fixed an issue where a VM would not be backed up if it were in the state "saved" and was present in the user configured VM list text file.
* Added user feedback - make backup success or fail clear in the log and console.
* Added user feedback - add "VMs backed up x/x" to email subject for clear success/fail visibility.
* Added user feedback - Log can now be emailed to multiple addresses.
* Added checks and balances to help with configuration as I'm very aware that the initial configuration can be troublesome. Running the utility manually is a lot more friendly and step-by-step now.
* Added -Help to give usage instructions in the terminal. Running the script with no options will also trigger the -help switch.
* Cleaned user entered paths so that trailing slashes no longer break things or have otherwise unintended results.
* Added -LogRotate [days] to removed old logs created by the utility.
* Streamlined config report so non configured options are not shown.
* Added donation link to the ASCII banner.
* Cleaned up code, removed unneeded log noise.

### 2022-03-27: Version 22.03.26

* Made a small fix to the 'NoPerms' function: The VM will be left in the state it was found. For example, when a VM is found in an offline state, the script will not start the VM once the backup is complete. In the previous version the VM would be started regardless of what state it was in previously.

### 2022-02-08: Version 22.02.08

* Added fix for potential BSOD on Windows Server 2016 Hyper-V host when exporting VMs using VSS. The change to the registry will only happen if Windows Server 2016 is detected as the Hyper-V host and only if the registry value is in the default state. If it has been configured previously no change will be made. [Issue 17 on GitHub](https://github.com/Digressive/HyperV-Backup-Utility/issues/17)

### 2022-01-20: Version 22.01.19

* When using -NoPerms the utility now waits for disk merging to complete before backing up.
* Utility now ignores blanks lines in VM list file.
* Added checks for success or failure in the backup, copy/compression process. If it fails none of the previous backups should be removed.

### 2021-12-28: Version 21.12.28

* Put checks in place so if a VM fails to backup the old backup for that VM is not removed and the error is logged.

### 2021-11-12: Version 21.11.09

* Added more logging info, clearer formatting.

### 2021-11-05: Version 21.11.05

* Fixed an error when moving compressed backup files from a working directory.
* Configured logs path now is created, if it does not exist.
* Added OS version info.
* Improved log output, added more information for each stage of the backup.

### 2021-08-10: Version 21.08.10

* Added an option to specify the Port for SMTP communication.

### 2021-07-02: Version 21.07.02

* Fixed many bugs introduced with implementing more 7-zip options. 7-zip options I've tested fully are '-t' archive type, '-p' password and '-v' split files.
* Implemented and automated a formal testing process.

### 2021-06-14: Version 21.06.14

* Replaced -Sz* specific options with -SzOptions which will support any option that 7-zip supports.

### 2021-06-02: Version 21.06.02

* Fixed an error where file types which are not .zip were not being moved from the working directory to the final backup location.

### 2021-05-30: Version 21.05.30

* Added additional 7-Zip options. -SzSplit to split archives into configuration volumes.
* Changed existing switches for 7-Zip options. Users must now add an additional hyphen '-' for 7-Zip options. This has been done to better support features that 7-Zip supports.
* Changed how old files are removed. Users should take extra care if they are storing non back-up files in the backup location. This has been done so that 7-Zip's split function can be supported.

### 2020-07-13: Version 20.07.13

* Added -ShortDate option. This will create backups with only the Year, Month, Day as the file name.
* Added pass through for 7-Zip options - CPU threads to use and compression level.
* Added proper error handling so errors are properly reported in the console, log and email.
* Bug fixes to create folders when paths are configured without the folders existing.

### 2020-02-28: Version 20.02.28 ‘Artifact’

* Fixed e-mail report extra line breaks in Outlook 365, Version 2001.
* Config report matches design of Image Factory Utility.
* Improved and simplified code.

### 2020-02-18: Version 2020.02.14 ‘Valentine’

Current known issues:

* E-mail report has extra line breaks in Outlook 365, Version 2001.

New features:

* Refactored code.
* Fully backwards compatible.
* Added option to use a working directory to stage backups before moving them to final backup location.
* Added option to use 7-Zip for backup compression.
* Added ASCII banner art when run in the console.
* Added option to disable the ASCII banner art.

### 2019-09-04 v4.5

* Added custom subject line for e-mail.

### 2019-05-26 v4.4

* Added more feedback when the script is used interactively.

### 2018-06-21 v4.3

* Added the ability to specify the VMs to be backed up using a txt file.

### 2018-03-04 v4.2

* Improved logging slightly to be clearer about which VM's previous backups are being deleted.

### 2018-03-03 v4.1

* Added option to compress the VM backups to a zip file. This option will remove the original VM backup.
* Added option to keep a configurable number of days’ worth of backups, so you can keep a history/archive of previous backups. Every effort has been taken to only remove backup files or folders generated by this utility.
* Changed the script so that when backup is complete, the VM backup folders/zip files will be have the time and date append to them.

### 2018-01-15 v4.0

* The backup script no longer creates a folder named after the Host server. The VM backups are placed in the root of the specified backup location.
* Fixed a small issue with logging where the script completes the backup process, then states incorrectly "there are no VMs to backup".

### 2018-01-12 v3.9

* Fixed a small bug that occurred when there were no VMs to backup, the script incorrectly logged an error in exporting the VMs. It now states that that are no VMs to backup.

### 2018-01-12 v3.8

* The script has been tested performing backups of Virtual Machines running on a Hyper-V cluster.
* Minor update to documentation.

### 2017-10-16 v3.7

* Changed SMTP authentication to require an encrypted password file.
* Added instructions on how to generate an encrypted password file.

### 2017-10-07 v3.6

* Added necessary information to add the script to the PowerShell Gallery.

### 2017-09-18 v3.5

* Improved the log output to be easier to read.

### 2017-07-22 v3.4

* Improved commenting on the code for documentation purposes.
* Added authentication and SSL options for e-mail notification.

### 2017-05-20 v3.3

* Added configuration via command line switches.
* Added option to perform regular online export if destination allows it.

### 2017-04-24 Minor Update

* Cleaned up the formatting and commented sections of the script.

### 2017-04-21 Minor Update

* Added the ability to email the log file when the script completes.
