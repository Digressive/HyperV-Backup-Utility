# HyperV Backup Utility

PowerShell script to backup Hyper-V VMs

My Hyper-V Backup Utility PowerShell script can also be downloaded from:

* [The Microsoft TechNet Gallery](https://gallery.technet.microsoft.com/PowerShell-Hyper-V-Backup-7d444752)
* [The PowerShell Gallery](https://www.powershellgallery.com/packages/Hyper-V-Backup)
* For full instructions and documentation, [visit my blog post](https://gal.vin/2017/09/18/vm-backup-for-hyper-v)

-Mike

Tweet me if you have questions: [@mikegalvin_](https://twitter.com/mikegalvin_)

## Features and Requirements

* The script is designed to be run on a Hyper-V host.
* The device must also have Hyper-V management tools and PowerShell modules installed.
* The script can be used to backup VMs to a device which the Hyper-V host does not have the access to run a regular export.
* The script can be used to backup VMs in a Hyper-V cluster.
* The script requires at least PowerShell 5.0

The script has been tested on Windows 10, Windows Server 2016 (Datacenter and Core installations) and Windows Server 2012 R2 (Datacenter and Core Installations) with PowerShell 5.0.

### Should You Use The -NoPerms Switch

The -NoPerms switch is intended as a workaround when used in an environment where the Hyper-V host can not be given the required permissions to run a regular export operation. If you are unsure, you should do a test run of the script without the -NoPerms switch first and see if you run into problems.

### Why Is The -NoPerms Switch Needed

Hyper-V’s export operation requires that the computer account in Active Directory have access to the location where the exports are being saved. I recommend creating an Active Directory group for the Hyper-V hosts and then giving the group the required ‘Full Control’ file and share permissions. When a NAS such as a QNAP device is intended to be used as an export location, Hyper-V will not be able to complete the operation as the computer account will not have access to the share on the NAS. Unfortunately to copy all the files necessary for a complete backup, the VM must be in an offline state for the operation to be completed, so the VM will be shutdown for the duration of the copy process when the -NoPerms switch is used.

### Generating A Password File

The password used for SMTP server authentication must be in an encrypted text file. To generate the password file, run the following command in PowerShell, on the computer that is going to run the script and logged in with the user that will be running the script. When you run the command you will be prompted for a username and password. Enter the username and password you want to use to authenticate to your SMTP server.

Please note: This is only required if you need to authenticate to the SMTP server when send the log via e-mail.

``` powershell
$creds = Get-Credential
$creds.Password | ConvertFrom-SecureString | Set-Content c:\scripts\ps-script-pwd.txt
```

After running the commands, you will have a text file containing the encrypted password. When configuring the -Pwd switch enter the path and file name of this file.

### Configuration

Here’s a list of all the command line switches and example configurations.

``` txt
-BackupTo
```

The path the Virtual Machines should be backed up to. A folder will be created in the specified path and each VM will have it's own folder inside.

``` txt
-List
```

Enter the path to a txt file with a list of Hyper-V VM names to backup. If this option is not configured, all running VMs will be backed up.

``` txt
-L
```

The path to output the log file to. The file name will be Hyper-V-Backup-YYYY-MM-dd-HH-mm-ss.log

``` txt
-NoPerms
```

Instructs the script to shutdown the running VM(s) to do the file-copy based backup, instead of using the Hyper-V export function. When multiple VMs are running, the first VM (alphabetically) will be shutdown, backed up, and then started, then the next and so on.

``` txt
-Keep
```

Instructs the script to keep a specified number of days worth of backups. The script will delete VM backups older than the number of days specified.

``` txt
-Compress
```

This option will create a .zip file of each Hyper-V VM backup. Available disk space should be considered when using this option.

``` txt
-Subject
```

The email subject that the email should have. Encapulate with single or double quotes.

``` txt
-SendTo
```

The e-mail address the log should be sent to.

``` txt
-From
```

The e-mail address the log should be sent from.

``` txt
-Smtp
```

The DNS name or IP address of the SMTP server.

``` txt
-User

``` txt
The user account to connect to the SMTP server.

``` txt
-Pwd
```

The txt file containing the encrypted password for the user account.

``` txt
-UseSsl
```

Configures the script to connect to the SMTP server using SSL.

### Example

``` txt
Hyper-V-Backup.ps1 -BackupTo \\nas\vms -List C:\scripts\vms.txt -NoPerms -Keep 30 -Compress -L C:\scripts\logs -Subject 'Server: Hyper-V Backup' -SendTo me@contoso.com -From hyperv@contoso.com -Smtp smtp.outlook.com -User user -Pwd C:\foo\pwd.txt -UseSsl
```

This will shutdown all the VMs listed in the file located in C:\scripts\vms.txt, and back up their files to \\nas\vms. Each VM will have their own folder. A zip file for each VM folder will be created, and the folder will be deleted. Any backups older than 30 days will also be deleted. The log file will be output to C:\scripts\logs and sent via e-mail with a custom subject line.
