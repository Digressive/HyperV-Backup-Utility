# HyperV-Backup-Utility
PowerShell script to backup Hyper-V VMs

My Hyper-V Backup Utility PowerShell script can also be downloaded from:
The Microsoft TechNet Gallery: https://gallery.technet.microsoft.com/PowerShell-Hyper-V-Backup-7d444752
The PowerShell Gallery: https://www.powershellgallery.com/packages/Hyper-V-Backup

For full instructions and documentation, visit my blog post: https://gal.vin/2017/09/18/vm-backup-for-hyper-v/

-Mike

Tweet me if you have questions: @Digressive

 
Features and Requirements

The script is designed to be run on a Hyper-V host.
The device must also have Hyper-V management tools and PowerShell modules installed.
The script can be used to backup VMs to a device which the Hyper-V host does not have the access to run a regular export.
The script can be used to backup VMs in a Hyper-V cluster.
The script requires at least PowerShell 5.0

The script has been tested on Windows 10, Windows Server 2016 (Datacenter and Core installations) and Windows Server 2012 R2 (Datacenter and Core Installations) with PowerShell 5.0.


Should You Use The -NoPerms Switch?

The -NoPerms switch is intended as a workaround when used in an environment where the Hyper-V host can not be given the required permissions to run a regular export operation. If you are unsure, you should do a test run of the script without the -NoPerms switch first and see if you run into problems.

Below are the operations the script performs with and without the -NoPerms switch.

When the -NoPerms switch is enabled:

Gracefully shutdown the first alphabetically named VM.
Copy all configuration, VHD, and snapshot/checkpoint files to the specified backup location.
Start the Virtual Machine, and move on to the next VM if applicable.
Optionally cleanup old backups or keep a configurable number of days worth of backups.
Optionally create a zip file of the export and remove the original backup folder.
Optionally create a log file and email it to an address of your choice.
When the -NoPerms switch is not enabled:

Run an export operation of each VM alphabetically, exporting the VMs to the specified backup location. The VMs are kept online.
Optionally cleanup old backups or keep a configurable number of days worth of backups.
Optionally create a zip file of the export and remove the original backup folder.
Optionally create a log file and email it to an address of your choice.
 

Why Is The -NoPerms Switch Needed?

Hyper-V’s export operation requires that the computer account in Active Directory have access to the location where the exports are being saved. I recommend creating an Active Directory group for the Hyper-V hosts and then giving the group the required ‘Full Control’ file and share permissions. When a NAS such as a QNAP device is intended to be used as an export location, Hyper-V will not be able to complete the operation as the computer account will not have access to the share on the NAS. Unfortunately to copy all the files necessary for a complete backup, the VM must be in an offline state for the operation to be completed, so the VM will be shutdown for the duration of the copy process when the -NoPerms switch is used.


Using This Script With A Hyper-V Cluster

I’ve tested the script backing up VMs running on a Hyper-V cluster and it works just as with standalone Hyper-V hosts. I recommend setting up a staggered Scheduled Task to run the script on each of the Hyper-V hosts in the cluster. The script will detect if there are any Virtual Machines with the status of ‘Running’ and perform a backup, as configured. The script can also be configured to accept a list of VMs via a TXT file, if this option is used the script will only look for the listed VMs and not any with the ‘Running’ status.


Generating A Password File

The password used for SMTP server authentication must be in an encrypted text file. To generate the password file, run the following command in PowerShell, on the computer that is going to run the script and logged in with the user that will be running the script. When you run the command you will be prompted for a username and password. Enter the username and password you want to use to authenticate to your SMTP server.

Please note: This is only required if you need to authenticate to the SMTP server when send the log via e-mail.

$creds = Get-Credential
$creds.Password | ConvertFrom-SecureString | Set-Content c:\scripts\ps-script-pwd.txt

After running the commands, you will have a text file containing the encrypted password. When configuring the -Pwd switch enter the path and file name of this file.


Configuration

Here’s a list of all the command line switches and example configurations.

-BackupTo
The path the Virtual Machines should be backed up to. A folder will be created in the specified path and each VM will have it's own folder inside.

-List 
Enter the path to a txt file with a list of Hyper-V VM names to backup. If this option is not configured, all running VMs will be backed up.

-L
The path to output the log file to. The file name will be Hyper-V-Backup-YYYY-MM-dd-HH-mm-ss.log

-NoPerms
Instructs the script to shutdown the running VM(s) to do the file-copy based backup, instead of using the Hyper-V export function. When multiple VMs are running, the first VM (alphabetically) will be shutdown, backed up, and then started, then the next and so on.

-Keep
Instructs the script to keep a specified number of days worth of backups. The script will delete VM backups older than the number of days specified.

-Compress
This option will create a .zip file of each Hyper-V VM backup. Available disk space should be considered when using this option.

-SendTo
The e-mail address the log should be sent to.

-From
The e-mail address the log should be sent from.

-Smtp
The DNS name or IP address of the SMTP server.

-User
The user account to connect to the SMTP server.

-Pwd
The txt file containing the encrypted password for the user account.

-UseSsl
Configures the script to connect to the SMTP server using SSL.

Example:
Hyper-V-Backup.ps1 -BackupTo \\nas\vms -List E:\scripts\vms.txt -NoPerms -Keep 30 -Compress -L E:\scripts -SendTo me@contoso.com -From hyperv@contoso.com -Smtp smtp.outlook.com -User user -Pwd C:\foo\pwd.txt -UseSsl

This will shutdown all the VMs listed in the file located in E:\scripts\vms.txt, and back up their files to \\nas\vms. Each VM will have their own folder. A zip file for each VM folder will be created, and the folder will be deleted. Any backups older than 30 days will also be deleted. The log file will be output to E:\scripts and sent via email.


Change Log

2018-06-21 Version 4.3
Added the ability to specify the VMs to be backed up using a txt file.

2018-03-04 Version 4.2
Improved logging slightly to be more clear about which VM’s previous backups are being deleted.

2018-03-03 Version 4.1
Added option to compress the VM backups to a zip file. This option will remove the original VM backup
Added option to keep a configurable number of days worth of backups, so you can keep a history/archive of previous backups. Every effort has been taken to only remove backup files or folders generated by this utility.
Changed the script so that when backup is complete, the VM backup folders/zip files will be have the time and date append to them.

2018-01-15 Version 4.0
The backup script no longer creates a folder named after the Host server. The VM backups are placed in the root of the specified backup location.
Fixed a small issue with logging where the script completes the backup process, then states incorrectly “there are no VMs to backup”.

2018-01-12 Version 3.9
Fixed a small bug that occurred when there were no VMs to backup, the script incorrectly logged an error in exporting the VMs. It now states that that are no VMs to backup.

2018-01-12 Version 3.8
The script has been tested performing backups of Virtual Machines running on a Hyper-V cluster.
Minor update to documentation.

2017-10-16 Version 3.7
Changed SMTP authentication to require an encrypted password file.
Added instructions on how to generate an encrypted password file.

2017-10-07 Version 3.6
Added necessary information to add the script to the PowerShell Gallery.

2017-09-18 Version 3.5
Improved the log output to be easier to read.

2017-07-22 Version 3.4
Improved commenting on the code for documentation purposes.
Added authentication and SSL options for e-mail notification.

2017-05-20 Version 3.3
Added configuration via command line switches.
Added option to perform regular online export if destination allows it.

2017-04-24 Minor Update
Cleaned up the formatting and commented sections of the script.

2017-04-21 Minor Update
Added the ability to email the log file when the script completes.
