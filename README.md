# Hyper-V Backup Utility

Flexible Hyper-V Backup Utility

``` txt
 _    _                    __      __  ____             _                  _    _ _   _ _ _ _         
| |  | |                   \ \    / / |  _ \           | |                | |  | | | (_) (_) |        
| |__| |_   _ _ __   ___ _ _\ \  / /  | |_) | __ _  ___| | ___   _ _ __   | |  | | |_ _| |_| |_ _   _ 
|  __  | | | | '_ \ / _ \ '__\ \/ /   |  _ < / _  |/ __| |/ / | | | '_ \  | |  | | __| | | | __| | | |
| |  | | |_| | |_) |  __/ |   \  /    | |_) | (_| | (__|   <| |_| | |_) | | |__| | |_| | | | |_| |_| |
|_|  |_|\__, | .__/ \___|_|    \/     |____/ \__,_|\___|_|\_\\__,_| .__/   \____/ \__|_|_|_|\__|\__, |
         __/ | |                                                  | |                            __/ |
        |___/|_|          Mike Galvin   https://gal.vin           |_|      Version 20.02.14 ♥   |___/ 
```

For full instructions and documentation, [visit my site.](https://gal.vin/2017/09/18/vm-backup-for-hyper-v)

Please consider supporting my work:

* Sign up [using Patreon.](https://www.patreon.com/mikegalvin)
* Support with a one-time payment [using PayPal.](https://www.paypal.me/digressive)

Hyper-V Backup Utility can also be downloaded from:

* [The Microsoft PowerShell Gallery](https://www.powershellgallery.com/packages/Hyper-V-Backup)

Tweet me if you have questions: [@mikegalvin_](https://twitter.com/mikegalvin_)

-Mike

## Features and Requirements

* It's designed to be run on a Hyper-V host.
* The Hyper-V host must have the Hyper-V management PowerShell modules installed.
* A leading feature is that the utility can be used to backup VMs to a device which the Hyper-V host does not have permission to run an regular export.
* The utility can be used to backup VMs from Hyper-V hosts in a cluster configuration.
* The utility requires at least PowerShell 5.0

This utility has been tested on Windows 10, Windows Server 2019, Windows Server 2016 and Windows Server 2012 R2 (Datacenter and Core Installations) with PowerShell 5.0.

### When you should use the -NoPerms switch

The -NoPerms switch is intended as a workaround when used in an environment where the Hyper-V host can not be given the required permissions to run a regular export to a remote device suce as a NAS device.

Hyper-V’s export operation requires that the computer account in Active Directory have access to the location where the exports are being stored. I recommend creating an Active Directory group for the Hyper-V hosts and then giving the group the required ‘Full Control’ file and share permissions. When a NAS, such as a QNAP device is intended to be used as an export location, Hyper-V will not be able to complete the operation as the computer account will not have access to the share on the NAS. To copy all the files necessary for a complete backup, the VM must be in an offline state for the operation to be completed, so the VM will be shutdown for the duration of the copy process when the -NoPerms switch is used.

### Generating A Password File

The password used for SMTP server authentication must be in an encrypted text file. To generate the password file, run the following command in PowerShell on the computer and logged in with the user that will be running the utility. When you run the command you will be prompted for a username and password. Enter the username and password you want to use to authenticate to your SMTP server.

Please note: This is only required if you need to authenticate to the SMTP server when send the log via e-mail.

``` powershell
$creds = Get-Credential
$creds.Password | ConvertFrom-SecureString | Set-Content c:\scripts\ps-script-pwd.txt
```

After running the commands, you will have a text file containing the encrypted password. When configuring the -Pwd switch enter the path and file name of this file.

### Configuration

Here’s a list of all the command line switches and example configurations.

| Command Line Switch | Description | Example |
| ------------------- | ----------- | ------- |
| -BackupTo | The path the virtual machines should be backed up to. Each VM will have its own folder inside this location. Do not add a trailing backslash. | \\nas\Backups OR E:\Backups |
| -List | Enter the path to a txt file with a list of Hyper-V VM names to backup. If this option is not configured, all running VMs will be backed up. | C:\scripts\vms.txt |
| -L | The path to output the log file to. The file name will be Hyper-V-Backup_YYYY-MM-dd_HH-mm-ss.log. Do not add a trailing \ backslash. | C:\foo |
| -Wd | The path to the working directory to use for the backup before copying it to the final backup directory. Use a directory on local fast media to improve performance. | C:\temp |
| -NoPerms | Configures the utility to shut down the running VM(s) to do the file-copy based backup instead of using the Hyper-V export function. If no list is specified and multiple VMs are running, the process will run through the VMs alphabetically. | N/A |
| -Keep | Instructs the utility to keep a specified number of days’ worth of backups. VM backups older than the number of days specified will be deleted. Every effort has been taken to only remove backup files or folders generated by this utility. | 30 |
| -Compress | This option will create a zip file of each Hyper-V VM backup. Available disk space should be considered when using this option. | N/A |
| -Sz | Configure the utility to use 7-Zip to compress the VM backups. 7-Zip must be installed in the default location ($env:ProgramFiles) if it is not found, Windows compression will be used as a fallback. | N/A |
| -NoBanner | Use this option to hide the ASCII art title in the console. | N/A |
| -Subject | The subject line for the e-mail log. Encapsulate with single or double quotes. If no subject is specified, the default of "Hyper-V Backup Utility Log" will be used. | 'Server: Notification' |
| -SendTo | The e-mail address the log should be sent to. | me@contoso.com |
| -From | The e-mail address the log should be sent from. | HyperV@contoso.com |
| -Smtp | The DNS name or IP address of the SMTP server. | smtp.live.com OR smtp.office365.com |
| -User | The user account to authenticate to the SMTP server. | example@contoso.com |
| -Pwd | The txt file containing the encrypted password for SMTP authentication. | C:\scripts\ps-script-pwd.txt |
| -UseSsl | Configures the utility to connect to the SMTP server using SSL. | N/A |

### Example

``` txt
Hyper-V-Backup.ps1 -BackupTo \\nas\vms -List C:\scripts\vms.txt -Wd C:\temp -Keep 30 -Compress -Sz -L C:\scripts\logs -Subject 'Server: Hyper-V Backup' -SendTo me@contoso.com -From hyperv@contoso.com -Smtp smtp.outlook.com -User user -Pwd C:\foo\pwd.txt -UseSsl
```

The above command will export the VMs listed in the file located in C:\scripts\vms.txt to C:\temp, compress the backups using 7-Zip and then move them to \\nas\vms. Any backups older than 30 days will also be deleted in the backup location. The log file will be output to C:\scripts\logs and sent via e-mail with a custom subject line.
