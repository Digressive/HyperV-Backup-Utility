# Hyper-V Backup Utility

Flexible Hyper-V Backup Utility

For full change log and more information, [visit my site.](https://gal.vin/utils/hyperv-backup-utility/)

Hyper-V Backup Utility is available from:

* [GitHub](https://github.com/Digressive/HyperV-Backup-Utility)
* [The Microsoft PowerShell Gallery](https://www.powershellgallery.com/packages/Hyper-V-Backup)

Please consider supporting my work:

* Sign up using [Patreon](https://www.patreon.com/mikegalvin).
* Support with a one-time donation using [PayPal](https://www.paypal.me/digressive).

If you’d like to contact me, please leave a comment, send me a [tweet or DM](https://twitter.com/mikegalvin_), or you can join my [Discord server](https://discord.gg/5ZsnJ5k).

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

## Generating A Password File

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
| -Webhook | The txt file containing the URI for a webhook to send the log file to. | [path\]webhook.txt |
| -Subject | Specify a subject line. If you leave this blank the default subject will be used | "'[Server: Notification]'" |
| -SendTo | The e-mail address the log should be sent to. For multiple address, separate with a comma. | [example@contoso.com] |
| -From | The e-mail address the log should be sent from. | [example@contoso.com] |
| -Smtp | The DNS name or IP address of the SMTP server. | [smtp server address] |
| -Port | The Port that should be used for the SMTP server. If none is specified then the default of 25 will be used. | [port number] |
| -User | The user account to authenticate to the SMTP server. | [example@contoso.com] |
| -Pwd | The txt file containing the encrypted password for SMTP authentication. | [path\]ps-script-pwd.txt |
| -UseSsl | Configures the utility to connect to the SMTP server using SSL. | N/A |

## Example

``` txt
[path\]Hyper-V-Backup.ps1 -BackupTo [path\]
```

This will backup all the VMs running to the backup location specified.
