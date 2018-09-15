﻿<#PSScriptInfo

.VERSION 4.3

.GUID c7fb05cc-1e20-4277-9986-523020060668

.AUTHOR Mike Galvin twitter.com/digressive

.COMPANYNAME

.COPYRIGHT (C) Mike Galvin. All rights reserved.

.TAGS Hyper-V Virtual Machines Cluster CSV Full Backup Export Permissions Zip History

.LICENSEURI

.PROJECTURI https://gal.vin/2017/09/18/vm-backup-for-hyper-v

.ICONURI

.EXTERNALMODULEDEPENDENCIES Windows 10/Windows Server 2016/Windows 2012 R2 Hyper-V PowerShell Management Modules

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES Hyper-V PowerShell Management Tools

.RELEASENOTES

#>

<#
    .SYNOPSIS
    Hyper-V Backup PowerShell Utility - Creates a full backup of running Hyper-V Virtual Machines.

    .DESCRIPTION
    This script creates a full backup of running Hyper-V Virtual Machines.

    This script will:
    
    Create a full backup of Virtual Machine(s), complete with configuration, snapshots/checkpoints, and VHD files.
    
    The -List switch should be used to specify a txt file with a list of VM names to backup. If this option is not
    configured, all running VMs will be backed up.

    If the -NoPerms switch is used, the script will shutdown the VM and copy all the files to the backup location, then start the VM.
    You should use the -NoPerms switch if Hyper-V does not have the appropriate permissions to the specified backup location to do an export.
    If the -NoPerms switch is NOT used, the script will use the built-in export function, and the VMs will continue to run.

    The -Keep switch should be used to keep the specified number of days worth of backups. For example, to keep one months worth of backups
    use -Keep 30.

    The -Compress switch should be used to generate a zip file of each VM that is backed up. The original backup folder will be deleted afterwards.

    Important note: This script should be run on a Hyper-V host. The Hyper-V PowerShell management modules should be installed.

    Please note: to send a log file using ssl and an SMTP password you must generate an encrypted
    password file. The password file is unique to both the user and machine.
    
    The command is as follows:

    $creds = Get-Credential
    $creds.Password | ConvertFrom-SecureString | Set-Content c:\foo\ps-script-pwd.txt
    
    .PARAMETER BackupTo
    The path the Virtual Machines should be backed up to.
    A folder will be created in the specified path and each VM will have it's own folder inside.

    .PARAMETER List
    Enter the path to a txt file with a list of Hyper-V VM names to backup. If this option is not configured, all running VMs will be backed up.

    .PARAMETER L
    The path to output the log file to.
    The file name will be Hyper-V-Backup-YYYY-MM-dd-HH-mm-ss.log

    .PARAMETER NoPerms
    Instructs the script to shutdown the running VM(s) to do the file-copy based backup, instead of using the Hyper-V export function.
    When multiple VMs are running, the first VM (alphabetically) will be shutdown, backed up, and then started, then the next and so on.

    .PARAMETER Keep
    Instructs the script to keep a specified number of days worth of backups. The script will delete VM backups older than the number of days specified.

    .PARAMETER Compress
    This option will create a .zip file of each Hyper-V VM backup. Available disk space should be considered when using this option.

    .PARAMETER SendTo
    The e-mail address the log should be sent to.

    .PARAMETER From
    The e-mail address the log should be sent from.

    .PARAMETER Smtp
    The DNS name or IP address of the SMTP server.

    .PARAMETER User
    The user account to connect to the SMTP server.

    .PARAMETER Pwd
    The txt file containing the encrypted password for the user account.

    .PARAMETER UseSsl
    Configures the script to connect to the SMTP server using SSL.

    .EXAMPLE
    Hyper-V-Backup.ps1 -BackupTo \\nas\vms -List E:\scripts\vms.txt -NoPerms -Keep 30 -Compress -L E:\scripts -SendTo me@contoso.com -From hyperv@contoso.com -Smtp smtp.outlook.com -User user -Pwd C:\foo\pwd.txt -UseSsl
    This will shutdown all the VMs listed in the file located in E:\scripts\vms.txt, and back up their files to \\nas\vms. Each VM will have their own folder. A zip file for each VM folder will be created, and the
    folder will be deleted. Any backups older than 30 days will also be deleted. The log file will be output to E:\scripts and sent via email.
#>

## Set up command line switches and what variables they map to.
[CmdletBinding()]
Param(
    [parameter(Mandatory=$True)]
    [alias("BackupTo")]
    $Backup,
    [alias("Keep")]
    $History,
    [alias("List")]
    [ValidateScript({Test-Path -Path $_ -PathType Leaf})]
    $VmList,
    [alias("L")]
    [ValidateScript({Test-Path $_ -PathType 'Container'})]
    $LogPath,
    [alias("SendTo")]
    $MailTo,
    [alias("From")]
    $MailFrom,
    [alias("Smtp")]
    $SmtpServer,
    [alias("User")]
    $SmtpUser,
    [alias("Pwd")]
    [ValidateScript({Test-Path -Path $_ -PathType Leaf})]
    $SmtpPwd,
    [switch]$Compress,
    [switch]$UseSsl,
    [switch]$NoPerms)

## If logging is configured, start logging.
If ($LogPath)
{
    $LogFile = ("Hyper-V-Backup-{0:yyyy-MM-dd-HH-mm-ss}.log" -f (Get-Date))
    $Log = "$LogPath\$LogFile"

    ## If the log file already exists, clear it.
    $LogT = Test-Path -Path $Log

    If ($LogT)
    {
        Clear-Content -Path $Log
    }

    Add-Content -Path $Log -Value "****************************************"
    Add-Content -Path $Log -Value "$(Get-Date -Format G) Log started"
    Add-Content -Path $Log -Value ""
}

## Set variables for computer name and get all running VMs.
$Vs = $Env:ComputerName

## If a VM list file is configured, backup the servers specified in the file.
If ($VmList)
{
    $Vms = Get-Content $VmList
}

## If a VM list file is not configured, back up the running VMs.
Else
{
    $Vms = Get-VM | Where-Object {$_.State -eq 'Running'} | Select-Object -ExpandProperty Name
}

## Check to see if there are any running VMs.
If ($Vms.count -ne 0)
{
    ## For logging.
    If ($LogPath)
    {
        Add-Content -Path $Log -Value "$(Get-Date -Format G) This virtual host is: $Vs"
        Add-Content -Path $Log -Value "$(Get-Date -Format G) The following VMs will be backed up:"

        ForEach ($Vm in $Vms)
        {
            Add-Content -Path $Log -Value "$Vm"
        }
    }

    ## If the NoPerms switch is set do the following commands.
    If ($NoPerms) 
    {
        ## For each VM do the following.
        ForEach ($Vm in $Vms)
        {
            $VmInfo = Get-VM -name $Vm

            ## Test for the existence of a previous VM export. If it exists, delete it.
            $VmExportBackupTest = Test-Path "$Backup\$Vm"
            If ($VmExportBackupTest -eq $True)
            {
                Remove-Item "$Backup\$Vm" -Recurse -Force
            }

            ## Create directories.
            New-Item "$Backup\$Vm" -ItemType Directory -Force
            New-Item "$Backup\$Vm\Virtual Machines" -ItemType Directory -Force
            New-Item "$Backup\$Vm\VHD" -ItemType Directory -Force
            New-Item "$Backup\$Vm\Snapshots" -ItemType Directory -Force
            
            ## For logging, test for creation of backup folders, report if they havn't been created.
            If ($LogPath)
            {
                $VmFolderTest = Test-Path "$Backup\$Vm\Virtual Machines"
                If ($VmFolderTest -eq $True)
                {
                    Add-Content -Path $Log -Value "$(Get-Date -Format G) Successfully created backup folder $Backup\$Vm\Virtual Machines"
                }

                Else
                {
                    Add-Content -Path $Log -Value "$(Get-Date -Format G) ERROR: There was a problem creating folder $Backup\$Vm\Virtual Machines"
                }

                $VmVHDTest = Test-Path "$Backup\$Vm\VHD"
                If ($VmVHDTest -eq $True)
                {
                    Add-Content -Path $Log -Value "$(Get-Date -Format G) Successfully created backup folder $Backup\$Vm\VHD"
                }

                Else
                {
                    Add-Content -Path $Log -Value "$(Get-Date -Format G) ERROR: There was a problem creating folder $Backup\$Vm\VHD"
                }
            
                $VmSnapTest = Test-Path "$Backup\$Vm\Snapshots"
                If ($VmSnapTest -eq $True)
                {
                    Add-Content -Path $Log -Value "$(Get-Date -Format G) Successfully created backup folder $Backup\$Vm\Snapshots"
                }

                Else
                {
                    Add-Content -Path $Log -Value "$(Get-Date -Format G) ERROR: There was a problem creating folder $Backup\$Vm\Snapshots"
                }
            }

            ## Stop the VM.
            Stop-VM $Vm

            ## For logging.
            If ($LogPath)
            {
                Add-Content -Path $Log -Value "$(Get-Date -Format G) Stopping VM: $Vm"
            }

            ## Pause the script for 5 seconds.
            Start-Sleep -S 5

            ## Copy the config files and folders.
            Copy-Item "$($VmInfo.ConfigurationLocation)\Virtual Machines\$($VmInfo.id)" "$Backup\$Vm\Virtual Machines\" -Recurse -Force
            Copy-Item "$($VmInfo.ConfigurationLocation)\Virtual Machines\$($VmInfo.id).*" "$Backup\$Vm\Virtual Machines\" -Recurse -Force

            ## For logging.
            If ($LogPath)
            {
                $VmConfigTest = Test-Path "$Backup\$Vm\Virtual Machines\*"
                If ($VmConfigTest -eq $True)
                {
                    Add-Content -Path $Log -Value "$(Get-Date -Format G) Successfully copied $Vm configuration to $Backup\$Vm\Virtual Machines"
                }

                Else
                {
                    Add-Content -Path $Log -Value "$(Get-Date -Format G) ERROR: There was a problem copying the configuration for $Vm"
                }
            }

            ## Copy the VHD.
            Copy-Item $VmInfo.HardDrives.Path -Destination "$Backup\$Vm\VHD\" -Recurse -Force

            ## For logging.
            If ($LogPath)
            {
                $VmVHDCopyTest = Test-Path "$Backup\$Vm\VHD\*"
                If ($VmVHDCopyTest -eq $True)
                {
                    Add-Content -Path $Log -Value "$(Get-Date -Format G) Successfully copied $Vm VHDs to $Backup\$Vm\VHD"
                }

                Else
                {
                    Add-Content -Path $Log -Value "$(Get-Date -Format G) ERROR: There was a problem copying the VHDs for $Vm"
                }
            }

            ## Get the VM snapshots/checkpoints, if any.
            $Snaps = Get-VMSnapshot $Vm

            ## For each snapshot do the following.
            ForEach ($Snap in $Snaps)
            {
                ## Copy the snapshot config files and folders.
                Copy-Item "$($VmInfo.ConfigurationLocation)\Snapshots\$($Snap.id)" "$Backup\$Vm\Snapshots\" -Recurse -Force
                Copy-Item "$($VmInfo.ConfigurationLocation)\Snapshots\$($Snap.id).*" "$Backup\$Vm\Snapshots\" -Recurse -Force

                ## For logging.
                If ($LogPath)
                {
                    $VmSnapCopyTest = Test-Path "$Backup\$Vm\Snapshots\*"
                    If ($VmSnapCopyTest -eq $True)
                    {
                        Add-Content -Path $Log -Value "$(Get-Date -Format G) Successfully copied checkpoint configuration for $Backup\$Vm\Snapshots"
                    }

                    Else
                    {
                        Add-Content -Path $Log -Value "$(Get-Date -Format G) ERROR: There was a problem copying the checkpoint configuration for $Vm"
                    }
                }

                ## Copy the snapshot root VHD.
                Copy-Item $Snap.HardDrives.Path -Destination "$Backup\$Vm\VHD\" -Recurse -Force

                ## For logging.
                If ($LogPath)
                {
                    Add-Content -Path $Log -Value "$(Get-Date -Format G) Successfully copied checkpoint VHDs for $Vm to $Backup\$Vm\VHD"
                }
            }

            ## Start the VM.
            Start-VM $Vm

            ## For logging.
            If ($LogPath)
            {
                Add-Content -Path $Log -Value "$(Get-Date -Format G) Starting VM: $Vm"
            }

            ## Pause the script for 30 seconds before proceeding.
            Start-Sleep -S 30

            ## If the keep option is not configured.
            If ($History -eq $Null)
            {
                ## If the compress option is not configured.
                If ($Compress -eq $False)
                {
                    ## Remove all previous backup folders.
                    Get-ChildItem -Path $Backup -Filter "$Vm-*-*-*-*-*-*" -Directory | Remove-Item -Recurse -Force

                    ## For logging.
                    If ($LogPath)
                    {
                        Add-Content -Path $Log -Value "$(Get-Date -Format G) Removing previous backup folders."
                    }
                }
            }

            ## If the keep option is configured.
            Else
            {
                ## If the compress option is not configured.
                If ($Compress -eq $False)
                {
                    ## Remove all previous backup folder that are older than the configured number of days.
                    Get-ChildItem -Path $Backup -Filter "$Vm-*-*-*-*-*-*" -Directory | Where-Object CreationTime –lt (Get-Date).AddDays(-$History) | Remove-Item -Recurse -Force

                    ## For logging.
                    If ($LogPath)
                    {
                        Add-Content -Path $Log -Value "$(Get-Date -Format G) Removing backup folders older than: $History days"
                    }
                }
            }

            ## If the compress option is configured.
            If ($Compress)
            {
                ## If the keep option is not configured.
                If ($History -eq $Null)
                {
                    ## Remove all previous compressed backups.
                    Remove-Item "$Backup\$Vm-*-*-*-*-*-*.zip" -Force

                    ## For logging.
                    If ($LogPath)
                    {
                        Add-Content -Path $Log -Value "$(Get-Date -Format G) Removing previous compressed backups."
                    }
                }

                ## If the keep option is configured.
                Else
                {
                    ## Remove previous compressed backups that are older than the configured number of days.
                    Get-ChildItem -Path "$Backup\$Vm-*-*-*-*-*-*.zip" | Where-Object CreationTime –lt (Get-Date).AddDays(-$History) | Remove-Item -Force

                    ## For logging.
                    If ($LogPath)
                    {
                        Add-Content -Path $Log -Value "$(Get-Date -Format G) Removing compressed backups older than: $History days"
                    }
                }

                ## Compress the VM backup into a zip, and delete the VM export folder.
                Add-Type -AssemblyName "system.io.compression.filesystem"
                [io.compression.zipfile]::CreateFromDirectory("$Backup\$Vm", "$Backup\$Vm-{0:yyyy-MM-dd-HH-mm-ss}.zip" -f (Get-Date))
                Get-ChildItem -Path $Backup -Filter "$Vm" -Directory | Remove-Item -Recurse -Force

                ## For logging.
                If ($LogPath)
                {
                    Add-Content -Path $Log -Value "$(Get-Date -Format G) Successfully created compressed backup of $Vm"
                }
            }
        
            ## If the compress option is not configured.
            Else
            {
                ## Rename the export of each VM to include the date.
                Get-ChildItem -Path $Backup -Filter $Vm -Directory | Rename-Item -NewName ("$Backup\$Vm-{0:yyyy-MM-dd-HH-mm-ss}" -f (Get-Date))
            }

            ## Pause the script for 30 seconds before proceeding.
            Start-Sleep -S 30
        }
    }

    ## If the NoPerms option is not set.
    Else
    {
        ForEach ($Vm in $Vms)
        {
            ## Test for the existence of a previous VM export. If it exists, delete it otherwise the export will fail.
            $VmExportBackupTest = Test-Path "$Backup\$Vm"
            If ($VmExportBackupTest -eq $True)
            {
                Remove-Item "$Backup\$Vm" -Recurse -Force
            }
        }

        ## Do a regular export of the VMs.
        If ($LogPath)
        {
            start-transcript -append -path $log
        }
        $Vms | Export-VM -Path "$Backup"
        If ($LogPath)
        {
            stop-transcript
        }

        ## For logging.
        If ($LogPath)
        {
            $VmExportTest = Test-Path "$Backup\*"
            If ($VmExportTest -eq $True)
            {
                Add-Content -Path $Log -Value "$(Get-Date -Format G) Successfully exported specified VMs to $Backup"
            }

            Else
            {
                Add-Content -Path $Log -Value "$(Get-Date -Format G) ERROR: There was a problem exporting the specified VMs to $Backup"
            }
        }

        ## Loop through the VMs do perform operations for the keep and compress options, if configured.
        ForEach ($Vm in $Vms)
        {
            ## If the keep option is not configured.
            If ($History -eq $Null)
            {
                ## If the compress option is not configured.
                If ($Compress -eq $False)
                {
                    ## Remove all previous backup folders.
                    Get-ChildItem -Path $Backup -Filter "$Vm-*-*-*-*-*-*" -Directory | Remove-Item -Recurse -Force

                    ## For logging.
                    If ($LogPath)
                    {
                        Add-Content -Path $Log -Value "$(Get-Date -Format G) Removing previous backup folders"
                    }
                }
            }

            ## If the keep option is configured.
            Else
            {
                ## If the compress option is not configured.
                If ($Compress -eq $False)
                {
                    ## Remove previous backup folders older than the configured number of days.
                    Get-ChildItem -Path $Backup -Filter "$Vm-*-*-*-*-*-*" -Directory | Where-Object CreationTime –lt (Get-Date).AddDays(-$History) | Remove-Item -Recurse -Force

                    ## For logging.
                    If ($LogPath)
                    {
                        Add-Content -Path $Log -Value "$(Get-Date -Format G) Removing backup folders older than: $History days"
                    }
                }
            }

            ## If the compress option is enabled.
            If ($Compress)
            {
                ## If the keep option is not configured.
                If ($History -eq $Null)
                {
                    ## Remove all previous compressed backups.
                    Remove-Item "$Backup\$Vm-*-*-*-*-*-*.zip" -Force

                    ## For logging.
                    If ($LogPath)
                    {
                        Add-Content -Path $Log -Value "$(Get-Date -Format G) Removing previous compressed backups"
                    }
                }

                ## If the keep option is configured.
                Else
                {
                    ## Remove previous compressed backups older than the configured number of days.
                    Get-ChildItem -Path "$Backup\$Vm-*-*-*-*-*-*.zip" | Where-Object CreationTime –lt (Get-Date).AddDays(-$History) | Remove-Item -Force

                    ## For logging.
                    If ($LogPath)
                    {
                        Add-Content -Path $Log -Value "$(Get-Date -Format G) Removing compressed backups older than: $History days"
                    }
                }

                ## Compress the VM backup into a zip, and delete the VM export folder.
                Add-Type -AssemblyName "system.io.compression.filesystem"
                [io.compression.zipfile]::CreateFromDirectory("$Backup\$Vm", "$Backup\$Vm-{0:yyyy-MM-dd-HH-mm-ss}.zip" -f (Get-Date))
                Get-ChildItem -Path $Backup -Filter "$Vm" -Directory | Remove-Item -Recurse -Force

                ## For logging.
                If ($LogPath)
                {
                    Add-Content -Path $Log -Value "$(Get-Date -Format G) Successfully created compressed backup of $Vm"
                }
            }
        
            ## If the compress option is not enabled.
            Else
            {
                ## Rename the export of each VM to include the date.
                Get-ChildItem -Path $Backup -Filter $Vm -Directory | Rename-Item -NewName ("$Backup\$Vm-{0:yyyy-MM-dd-HH-mm-ss}" -f (Get-Date))
            }
        }
    }
}

## If there are no VMs, then do nothing.
Else
{
    ## For Logging.
    If ($LogPath)
    {
        Add-Content -Path $Log -Value "$(Get-Date -Format G) There are no VMs running to backup"
    }
}

## If log was configured stop the log.
If ($LogPath)
{
    Add-Content -Path $Log -Value ""
    Add-Content -Path $Log -Value "$(Get-Date -Format G) Log finished"
    Add-Content -Path $Log -Value "****************************************"

    ## If email was configured, set the variables for the email subject and body.
    If ($SmtpServer)
    {
        $MailSubject = "Hyper-V Backup Log"
        $MailBody = Get-Content -Path $Log | Out-String

        ## If an email password was configured, create a variable with the username and password.
        If ($SmtpPwd)
        {
            $SmtpPwdEncrypt = Get-Content $SmtpPwd | ConvertTo-SecureString
            $SmtpCreds = New-Object System.Management.Automation.PSCredential -ArgumentList ($SmtpUser, $SmtpPwdEncrypt)

            ## If ssl was configured, send the email with ssl.
            If ($UseSsl)
            {
                Send-MailMessage -To $MailTo -From $MailFrom -Subject $MailSubject -Body $MailBody -SmtpServer $SmtpServer -UseSsl -Credential $SmtpCreds
            }

            ## If ssl wasn't configured, send the email without ssl.
            Else
            {
                Send-MailMessage -To $MailTo -From $MailFrom -Subject $MailSubject -Body $MailBody -SmtpServer $SmtpServer -Credential $SmtpCreds
            }
        }

        ## If an email username and password were not configured, send the email without authentication.
        Else
        {
            Send-MailMessage -To $MailTo -From $MailFrom -Subject $MailSubject -Body $MailBody -SmtpServer $SmtpServer
        }
    }
}

## End
