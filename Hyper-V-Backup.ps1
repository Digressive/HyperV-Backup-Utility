<#PSScriptInfo

.VERSION 22.06.22

.GUID c7fb05cc-1e20-4277-9986-523020060668

.AUTHOR Mike Galvin Contact: mike@gal.vin / twitter.com/mikegalvin_ / discord.gg/5ZsnJ5k

.COMPANYNAME Mike Galvin

.COPYRIGHT (C) Mike Galvin. All rights reserved.

.TAGS Hyper-V Virtual Machines Full Backup Export Permissions Zip History 7-Zip

.LICENSEURI

.PROJECTURI https://gal.vin/utils/hyperv-backup-utility/

.ICONURI

.EXTERNALMODULEDEPENDENCIES Hyper-V Management Modules

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES

#>

<#
    .SYNOPSIS
    Hyper-V Backup Utility - Flexible backup of Hyper-V Virtual Machines.

    .DESCRIPTION
    Creates a full backup of virtual machines.
    Run with -help or no arguments for usage.
#>

## Set up command line switches.
[CmdletBinding()]
Param(
    [alias("BackupTo")]
    $BackupUsr,
    [alias("Keep")]
    $History,
    [alias("List")]
    [ValidateScript({Test-Path -Path $_ -PathType Leaf})]
    $VmList,
    [alias("Wd")]
    $WorkDirUsr,
    [alias("SzOptions")]
    $SzSwitches,
    [alias("L")]
    $LogPathUsr,
    [alias("LogRotate")]
    $LogHistory,
    [alias("Subject")]
    $MailSubject,
    [alias("SendTo")]
    $MailTo,
    [alias("From")]
    $MailFrom,
    [alias("Smtp")]
    $SmtpServer,
    [alias("Port")]
    $SmtpPort,
    [alias("User")]
    $SmtpUser,
    [alias("Pwd")]
    [ValidateScript({Test-Path -Path $_ -PathType Leaf})]
    $SmtpPwd,
    [switch]$UseSsl,
    [switch]$NoPerms,
    [switch]$Compress,
    [switch]$Sz,
    [switch]$ShortDate,
    [switch]$Help,
    [switch]$NoBanner)

If ($NoBanner -eq $False)
{
    Write-Host -ForegroundColor Yellow -BackgroundColor Black -Object "
     _    _                    __      __  ____             _                  _    _ _   _ _ _ _             
    | |  | |                   \ \    / / |  _ \           | |                | |  | | | (_) (_) |            
    | |__| |_   _ _ __   ___ _ _\ \  / /  | |_) | __ _  ___| | ___   _ _ __   | |  | | |_ _| |_| |_ _   _     
    |  __  | | | | '_ \ / _ \ '__\ \/ /   |  _ < / _  |/ __| |/ / | | | '_ \  | |  | | __| | | | __| | | |    
    | |  | | |_| | |_) |  __/ |   \  /    | |_) | (_| | (__|   <| |_| | |_) | | |__| | |_| | | | |_| |_| |    
    |_|  |_|\__, | .__/ \___|_|    \/     |____/ \__,_|\___|_|\_\\__,_| .__/   \____/ \__|_|_|_|\__|\__, |    
             __/ | |                                                  | |                            __/ |    
            |___/|_|                                                  |_|                           |___/     
                              Mike Galvin   https://gal.vin                     Version 22.06.22              
                         Donate: https://www.paypal.me/digressive             See -help for usage             
"
}

If ($PSBoundParameters.Values.Count -eq 0 -or $Help)
{
    Write-Host -Object "Usage:
    From a terminal run: [path\]Hyper-V-Backup.ps1 -BackupTo [path\]
    This will backup all the VMs running to the backup location specified.

    Use -List [path\]vms.txt to specify a list of vm names to backup.
    Use -Wd [path\] to configure a working directory for the backup process.
    Use -Keep [number] to specify how many days worth of backup to keep.
    Use -ShortDate to use only the Year, Month and Day in backup filenames.

    -NoPerms should only be used when a regular backup cannot be performed.
    Please note: this will cause the VMs to shutdown during the backup process.

    Use -Compress to compress the VM backups in a zip file using Windows compression.
    Use -Sz to use 7-zip 
    Use -SzOptions ""'-t7z,-v2g,-ppassword'"" to specify 7-zip options like file type, split files or password.

    To output a log: -L [path\].
    To remove logs produced by the utility older than X days: -LogRotate [number].
    Run with no ASCII banner: -NoBanner

    To use the 'email log' function:
    Specify the subject line with -Subject ""'[subject line]'"" If you leave this blank a default subject will be used
    Make sure to encapsulate it with double & single quotes as per the example for Powershell to read it correctly.

    Specify the 'to' address with -SendTo [example@contoso.com]
    For multiple address, separate with a comma.

    Specify the 'from' address with -From [example@contoso.com]
    Specify the SMTP server with -Smtp [smtp server name]

    Specify the port to use with the SMTP server with -Port [port number].
    If none is specified then the default of 25 will be used.

    Specify the user to access SMTP with -User [example@contoso.com]
    Specify the password file to use with -Pwd [path\]ps-script-pwd.txt.
    Use SSL for SMTP server connection with -UseSsl.

    To generate an encrypted password file run the following commands
    on the computer and the user that will run the script:
"
    Write-Host -Object '    $creds = Get-Credential
    $creds.Password | ConvertFrom-SecureString | Set-Content [path\]ps-script-pwd.txt'
}

else {
    ## If logging is configured, start logging.
    ## If the log file already exists, clear it.
    If ($LogPathUsr)
    {
        ## Clean User entered string
        $LogPath = $LogPathUsr.trimend('\')

        ## Make sure the log directory exists.
        If ((Test-Path -Path $LogPath) -eq $False)
        {
            New-Item $LogPath -ItemType Directory -Force | Out-Null
        }

        $LogFile = ("Hyper-V-Backup_{0:yyyy-MM-dd_HH-mm-ss}.log" -f (Get-Date))
        $Log = "$LogPath\$LogFile"

        If (Test-Path -Path $Log)
        {
            Clear-Content -Path $Log
        }
    }

    ## Function to get date in specific format.
    Function Get-DateFormat
    {
        Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }

    Function Get-DateShort
    {
        Get-Date -Format "yyyy-MM-dd"
    }

    Function Get-DateLong
    {
        Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    }

    ## Function for logging.
    Function Write-Log($Type, $Evt)
    {
        If ($Type -eq "Info")
        {
            If ($LogPathUsr)
            {
                Add-Content -Path $Log -Encoding ASCII -Value "$(Get-DateFormat) [INFO] $Evt"
            }

            Write-Host -Object "$(Get-DateFormat) [INFO] $Evt"
        }

        If ($Type -eq "Succ")
        {
            If ($LogPathUsr)
            {
                Add-Content -Path $Log -Encoding ASCII -Value "$(Get-DateFormat) [SUCCESS] $Evt"
            }

            Write-Host -ForegroundColor Green -Object "$(Get-DateFormat) [SUCCESS] $Evt"
        }

        If ($Type -eq "Err")
        {
            If ($LogPathUsr)
            {
                Add-Content -Path $Log -Encoding ASCII -Value "$(Get-DateFormat) [ERROR] $Evt"
            }

            Write-Host -ForegroundColor Red -BackgroundColor Black -Object "$(Get-DateFormat) [ERROR] $Evt"
        }

        If ($Type -eq "Conf")
        {
            If ($LogPathUsr)
            {
                Add-Content -Path $Log -Encoding ASCII -Value "$Evt"
            }

            Write-Host -ForegroundColor Cyan -Object "$Evt"
        }
    }

    ##
    ## Start of backup Options function
    ##
    Function OptionsRun
    {
        ## For 7zip, replace . dots with - hyphens in the vm name
        $BackupSucc = $false
        $VmFixed = $Vm.replace(".","-")

        ## Remove previous backup folders. -Keep switch and -Compress switch are NOT configured.
        If ($Null -eq $History -And $Compress -eq $False)
        {
            Write-Log -Type Info -Evt "(VM:$Vm) Removing previous backups"

            If ($ShortDate)
            {
                ## report old files to remove
                If ($LogPathUsr)
                {
                    Get-ChildItem -Path $WorkDir -Filter "$VmFixed-*-*-*" -Directory | Select-Object -Property Name, CreationTime | Format-Table -HideTableHeaders | Out-File -Append $Log -Encoding ASCII
                }

                ## remove old files
                Get-ChildItem -Path $WorkDir -Filter "$VmFixed-*-*-*" -Directory | Remove-Item -Recurse -Force
            }

            else {
                ## report old files to remove
                If ($LogPathUsr)
                {
                    Get-ChildItem -Path $WorkDir -Filter "$VmFixed-*-*-*_*-*-*" -Directory | Select-Object -Property Name, CreationTime | Format-Table -HideTableHeaders | Out-File -Append $Log -Encoding ASCII
                }

                ## remove old files
                Get-ChildItem -Path $WorkDir -Filter "$VmFixed-*-*-*_*-*-*" -Directory | Remove-Item -Recurse -Force
            }

            ## If working directory is configured by user, remove all previous backup folders
            If ($WorkDir -ne $Backup)
            {
                ## Make sure the backup directory exists.

                If (Test-Path -Path $Backup)
                {
                    If ($ShortDate)
                    {
                        ## report old files to remove
                        If ($LogPathUsr)
                        {
                            Get-ChildItem -Path $Backup -Filter "$VmFixed-*-*-*" -Directory | Select-Object -Property Name, CreationTime | Format-Table -HideTableHeaders | Out-File -Append $Log -Encoding ASCII
                        }

                        ## remove old files
                        Get-ChildItem -Path $Backup -Filter "$VmFixed-*-*-*" -Directory | Remove-Item -Recurse -Force
                    }

                    else {
                        ## report old files to remove
                        If ($LogPathUsr)
                        {
                            Get-ChildItem -Path $Backup -Filter "$VmFixed-*-*-*_*-*-*" -Directory | Select-Object -Property Name, CreationTime | Format-Table -HideTableHeaders | Out-File -Append $Log -Encoding ASCII
                        }

                        ## remove old files
                        Get-ChildItem -Path $Backup -Filter "$VmFixed-*-*-*_*-*-*" -Directory | Remove-Item -Recurse -Force
                    }
                }
            }
        }

        ## Remove previous backup folders older than X days. -Keep switch is configured and -Compress switch is NOT.
        else {
            If ($Compress -eq $False)
            {
                Write-Log -Type Info -Evt "(VM:$Vm) Removing backup folders older than: $History days"

                If ($ShortDate)
                {
                    ## report old files to remove
                    If ($LogPathUsr)
                    {
                        Get-ChildItem -Path $WorkDir -Filter "$VmFixed-*-*-*" -Directory | Where-Object CreationTime -lt (Get-Date).AddDays(-$History) | Select-Object -Property Name, CreationTime | Format-Table -HideTableHeaders | Out-File -Append $Log -Encoding ASCII
                    }

                    ## remove old files
                    Get-ChildItem -Path $WorkDir -Filter "$VmFixed-*-*-*" -Directory | Where-Object CreationTime -lt (Get-Date).AddDays(-$History) | Remove-Item -Recurse -Force
                }

                else {
                    ## report old files to remove
                    If ($LogPathUsr)
                    {
                        Get-ChildItem -Path $WorkDir -Filter "$VmFixed-*-*-*_*-*-*" -Directory | Where-Object CreationTime -lt (Get-Date).AddDays(-$History) | Select-Object -Property Name, CreationTime | Format-Table -HideTableHeaders | Out-File -Append $Log -Encoding ASCII
                    }

                    ## remove old files
                    Get-ChildItem -Path $WorkDir -Filter "$VmFixed-*-*-*_*-*-*" -Directory | Where-Object CreationTime -lt (Get-Date).AddDays(-$History) | Remove-Item -Recurse -Force
                }

                ## If working directory is configured by user, remove all previous backup folders older than X configured days.
                If ($WorkDir -ne $Backup)
                {
                    ## Make sure the backup directory exists.
                    If (Test-Path -Path $Backup)
                    {
                        If ($ShortDate)
                        {
                            ## report old files to remove
                            If ($LogPathUsr)
                            {
                                Get-ChildItem -Path $Backup -Filter "$VmFixed-*-*-*" -Directory | Where-Object CreationTime -lt (Get-Date).AddDays(-$History) | Select-Object -Property Name, CreationTime | Format-Table -HideTableHeaders | Out-File -Append $Log -Encoding ASCII
                            }

                            ## remove old files
                            Get-ChildItem -Path $Backup -Filter "$VmFixed-*-*-*" -Directory | Where-Object CreationTime -lt (Get-Date).AddDays(-$History) | Remove-Item -Recurse -Force
                        }

                        else {
                            ## report old files to remove
                            If ($LogPathUsr)
                            {
                                Get-ChildItem -Path $Backup -Filter "$VmFixed-*-*-*_*-*-*" -Directory | Where-Object CreationTime -lt (Get-Date).AddDays(-$History) | Select-Object -Property Name, CreationTime | Format-Table -HideTableHeaders | Out-File -Append $Log -Encoding ASCII
                            }

                            ## remove old files
                            Get-ChildItem -Path $Backup -Filter "$VmFixed-*-*-*_*-*-*" -Directory | Where-Object CreationTime -lt (Get-Date).AddDays(-$History) | Remove-Item -Recurse -Force
                        }
                    }
                }
            }
        }


        ## 2nd Function start here maybe
        ## Remove ALL previous backup files. -Keep switch is NOT configured and -Compress switch IS.
        If ($Compress)
        {
            If ($Null -eq $History)
            {
                Write-Log -Type Info -Evt "(VM:$Vm) Removing all previous compressed backups"

                If ($ShortDate)
                {
                    Remove-Item "$WorkDir\$VmFixed-*-*-*.*" -Force
                }

                else {
                    Remove-Item "$WorkDir\$VmFixed-*-*-*_*-*-*.*" -Force
                }

                ## If working directory is configured by user, remove all previous backup files.
                If ($WorkDir -ne $Backup)
                {
                    ## Make sure the backup directory exists.
                    If (Test-Path -Path $Backup)
                    {
                        If ($ShortDate)
                        {
                            Remove-Item "$Backup\$VmFixed-*-*-*.*" -Force
                        }

                        else {
                            Remove-Item "$Backup\$VmFixed-*-*-*_*-*-*.*" -Force
                        }
                    }
                }
            }

            ## Remove previous backup files older than X days. -Keep and -Compress switch are configured.
            else {
                Write-Log -Type Info -Evt "(VM:$Vm) Removing compressed backups older than: $History days"

                If ($ShortDate)
                {
                    ## report old files to remove
                    If ($LogPathUsr)
                    {
                        Get-ChildItem -Path "$WorkDir\$VmFixed-*-*-*.*" | Where-Object CreationTime -lt (Get-Date).AddDays(-$History) | Select-Object -Property Name, CreationTime | Format-Table -HideTableHeaders | Out-File -Append $Log -Encoding ASCII
                    }

                    ## remove old files
                    Get-ChildItem -Path "$WorkDir\$VmFixed-*-*-*.*" | Where-Object CreationTime -lt (Get-Date).AddDays(-$History) | Remove-Item -Force
                }

                else {
                    ## report old files to remove
                    If ($LogPathUsr)
                    {
                        Get-ChildItem -Path "$WorkDir\$VmFixed-*-*-*_*-*-*.*" | Where-Object CreationTime -lt (Get-Date).AddDays(-$History) | Select-Object -Property Name, CreationTime | Format-Table -HideTableHeaders | Out-File -Append $Log -Encoding ASCII
                    }

                    ## remove old files
                    Get-ChildItem -Path "$WorkDir\$VmFixed-*-*-*_*-*-*.*" | Where-Object CreationTime -lt (Get-Date).AddDays(-$History) | Remove-Item -Force
                }

                ## If working directory is configured by user, remove previous backup files older than X days.
                If ($WorkDir -ne $Backup)
                {
                    ## Make sure the backup directory exists.
                    If (Test-Path -Path $Backup)
                    {
                        If ($ShortDate)
                        {
                            ## report old files to remove
                            If ($LogPathUsr)
                            {
                                Get-ChildItem -Path "$Backup\$VmFixed-*-*-*.*" | Where-Object CreationTime -lt (Get-Date).AddDays(-$History) | Select-Object -Property Name, CreationTime | Format-Table -HideTableHeaders | Out-File -Append $Log -Encoding ASCII
                            }

                            ## remove old files
                            Get-ChildItem -Path "$Backup\$VmFixed-*-*-*.*" | Where-Object CreationTime -lt (Get-Date).AddDays(-$History) | Remove-Item -Force
                        }

                        else {
                            ## report old files to remove
                            If ($LogPathUsr)
                            {
                                Get-ChildItem -Path "$Backup\$VmFixed-*-*-*_*-*-*.*" | Where-Object CreationTime -lt (Get-Date).AddDays(-$History) | Select-Object -Property Name, CreationTime | Format-Table -HideTableHeaders | Out-File -Append $Log -Encoding ASCII
                            }

                            ## remove old files
                            Get-ChildItem -Path "$Backup\$VmFixed-*-*-*_*-*-*.*" | Where-Object CreationTime -lt (Get-Date).AddDays(-$History) | Remove-Item -Force
                        }
                    }
                }
            }

            ## 3rd Function here maybe
            ## If -Compress and -Sz are configured AND 7-zip is installed - compress the backup folder, if it isn't fallback to Windows compression.
            If ($Sz -eq $True -AND $7zT -eq $True)
            {
                Write-Log -Type Info -Evt "(VM:$Vm) Compressing backup using 7-Zip compression"

                ## If -ShortDate is configured, test for an old backup file, if true append a number (and increase the number if file still exists) before the file extension.
                If ($ShortDate)
                {
                    ## If using 7zip's split file feature with short dates, we need to handle the files a little differently.
                    If ($SzSwSplit -like "-v*")
                    {
                        $ShortDateT = Test-Path -Path ("$WorkDir\$VmFixed-$(Get-DateShort).*.*")

                        If ($ShortDateT)
                        {
                            Write-Log -Type Info -Evt "(VM:$Vm) File $VmFixed-$(Get-DateShort) already exists, appending number"
                            $i = 1
                            $ShortDateNN = ("$VmFixed-$(Get-DateShort)-{0:D3}" -f $i++)
                            $ShortDateExistT = Test-Path -Path "$WorkDir\$ShortDateNN.*.*"

                            If ($ShortDateExistT)
                            {
                                do {
                                    $ShortDateNN = ("$VmFixed-$(Get-DateShort)-{0:D3}" -f $i++)
                                    $ShortDateExistT = Test-Path -Path "$WorkDir\$ShortDateNN.*.*"
                                } until ($ShortDateExistT -eq $false)
                            }

                            ## 7-zip compression with shortdate configured and a number appended.
                            try {
                                & "$env:programfiles\7-Zip\7z.exe" $SzSwSplit -bso0 a ("$WorkDir\$ShortDateNN") "$WorkDir\$Vm\*"
                                $BackupSucc = $true
                            }
                            catch {
                                $_.Exception.Message | Write-Log -Type Err -Evt "(VM:$Vm) $_"
                                $BackupSucc = $false
                            }
                        }

                        else {
                            ## 7-zip compression with shortdate configured and no need for a number appended.
                            try {
                                & "$env:programfiles\7-Zip\7z.exe" $SzSwSplit -bso0 a ("$WorkDir\$VmFixed-$(Get-DateShort)") "$WorkDir\$Vm\*"
                                $BackupSucc = $true
                            }
                            catch {
                                $_.Exception.Message | Write-Log -Type Err -Evt "(VM:$Vm) $_"
                                $BackupSucc = $false
                            }
                        }
                    }

                    else
                    {
                        $ShortDateT = Test-Path -Path ("$WorkDir\$VmFixed-$(Get-DateShort).*")

                        If ($ShortDateT)
                        {
                            Write-Log -Type Info -Evt "(VM:$Vm) File $VmFixed-$(Get-DateShort) already exists, appending number"
                            $i = 1
                            $ShortDateNN = ("$VmFixed-$(Get-DateShort)-{0:D3}" -f $i++)
                            $ShortDateExistT = Test-Path -Path "$WorkDir\$ShortDateNN.*"

                            If ($ShortDateExistT)
                            {
                                do {
                                    $ShortDateNN = ("$VmFixed-$(Get-DateShort)-{0:D3}" -f $i++)
                                    $ShortDateExistT = Test-Path -Path "$WorkDir\$ShortDateNN.*"
                                } until ($ShortDateExistT -eq $false)
                            }

                            ## 7-zip compression with shortdate configured and a number appened.
                            try {
                                & "$env:programfiles\7-Zip\7z.exe" $SzSwSplit -bso0 a ("$WorkDir\$ShortDateNN") "$WorkDir\$Vm\*"
                                $BackupSucc = $true
                            }
                            catch {
                                $_.Exception.Message | Write-Log -Type Err -Evt "(VM:$Vm) $_"
                                $BackupSucc = $false
                            }
                        }

                        ## 7-zip compression with shortdate configured and no need for a number appened.
                        try {
                            & "$env:programfiles\7-Zip\7z.exe" $SzSwSplit -bso0 a ("$WorkDir\$VmFixed-$(Get-DateShort)") "$WorkDir\$Vm\*"
                            $BackupSucc = $true
                        }
                        catch {
                            $_.Exception.Message | Write-Log -Type Err -Evt "(VM:$Vm) $_"
                            $BackupSucc = $false
                        }
                    }
                }

                else {
                    ## 7-zip compression with longdate.
                    try {
                        & "$env:programfiles\7-Zip\7z.exe" $SzSwSplit -bso0 a ("$WorkDir\$VmFixed-$(Get-DateLong)") "$WorkDir\$Vm\*"
                        $BackupSucc = $true
                    }
                    catch {
                        $_.Exception.Message | Write-Log -Type Err -Evt "(VM:$Vm) $_"
                        $BackupSucc = $false
                    }
                }
            }

            ## Compress the backup folder using Windows compression. -Compress is configured, -Sz switch is not, or it is and 7-zip isn't detected.
            ## This is also the "fallback" windows compression code.
            else {
                Write-Log -Type Info -Evt "(VM:$Vm) Compressing backup using Windows compression"
                Add-Type -AssemblyName "system.io.compression.filesystem"

                If ($ShortDate)
                {
                    $ShortDateT = Test-Path -Path ("$WorkDir\$VmFixed-$(Get-DateShort).zip")

                    If ($ShortDateT)
                    {
                        Write-Log -Type Info -Evt "(VM:$Vm) File $VmFixed-$(Get-DateShort) already exists, appending number"
                        $i = 1
                        $ShortDateNN = ("$VmFixed-$(Get-DateShort)-{0:D3}.zip" -f $i++)
                        $ShortDateExistT = Test-Path -Path $WorkDir\$ShortDateNN

                        If ($ShortDateExistT)
                        {
                            do {
                                $ShortDateNN = ("$VmFixed-$(Get-DateShort)-{0:D3}.zip" -f $i++)
                                $ShortDateExistT = Test-Path -Path $WorkDir\$ShortDateNN
                            } until ($ShortDateExistT -eq $false)
                        }

                        ## Windows compression with shortdate configured and a number appended.
                        try {
                            [io.compression.zipfile]::CreateFromDirectory("$WorkDir\$Vm", ("$WorkDir\$ShortDateNN"))
                            $BackupSucc = $true
                        }
                        catch {
                            $_.Exception.Message | Write-Log -Type Err -Evt "(VM:$Vm) $_"
                            $BackupSucc = $false
                        }
                    }

                    else {
                        try {
                            [io.compression.zipfile]::CreateFromDirectory("$WorkDir\$Vm", ("$WorkDir\$VmFixed-$(Get-DateShort).zip"))
                            $BackupSucc = $true
                        }
                        catch {
                            $_.Exception.Message | Write-Log -Type Err -Evt "(VM:$Vm) $_"
                            $BackupSucc = $false
                        }
                    }
                }

                else {
                    try {
                        [io.compression.zipfile]::CreateFromDirectory("$WorkDir\$Vm", ("$WorkDir\$VmFixed-$(Get-DateLong).zip"))
                        $BackupSucc = $true
                    }
                    catch {
                        $_.Exception.Message | Write-Log -Type Err -Evt "(VM:$Vm) $_"
                        $BackupSucc = $false
                    }
                }
            }

            ## Remove the VMs export folder.
            If ($BackupSucc)
            {
                Get-ChildItem -Path $WorkDir -Filter "$Vm" -Directory | Remove-Item -Recurse -Force
            }

            else {
                Write-Log -Type Err -Evt "(VM:$Vm) Compressing backup failed."
            }

            ## If working directory has been configured by the user, move the compressed backup to the backup folder and rename to include the date.
            If ($WorkDir -ne $Backup)
            {
                ## Make sure the backup directory exists.
                If ((Test-Path -Path $Backup) -eq $False)
                {
                    Write-Log -Type Info -Evt "Backup directory $Backup doesn't exist. Creating it."
                    New-Item $Backup -ItemType Directory -Force | Out-Null
                }

                ## Get the exact name of the backup file and append numbers onto the filename, keeping the extension intact.
                If ($ShortDate)
                {
                    If ($SzSwSplit -like "-v*")
                    {
                        $SzSplitFiles = Get-ChildItem -Path ("$WorkDir\$VmFixed-$(Get-DateShort).*.*") -File
                        
                        ForEach ($SplitFile in $SzSplitFiles) {
                            $ShortDateT = Test-Path -Path "$Backup\$($SplitFile.name)"

                            If ($ShortDateT)
                            {
                                Write-Log -Type Info -Evt "(VM:$Vm) File $($SplitFile.name) already exists, appending number"
                                $FileExist = Get-ChildItem -Path "$Backup\$($SplitFile.name)" -File
                                $i = 1

                                $ShortDateNN = ("$VmFixed-$(Get-DateShort)-{0:D3}" -f $i++ + $FileExist.Extension)
                                $ShortDateExistT = Test-Path -Path $Backup\$ShortDateNN

                                If ($ShortDateExistT)
                                {
                                    do {
                                        $ShortDateNN = ("$VmFixed-$(Get-DateShort)-{0:D3}" -f $i++ + $FileExist.Extension)
                                        $ShortDateExistT = Test-Path -Path $Backup\$ShortDateNN
                                    } until ($ShortDateExistT -eq $false)
                                }

                                try {
                                    Get-ChildItem -Path $SplitFile | Move-Item -Destination $Backup\$ShortDateNN -ErrorAction 'Stop'
                                }
                                catch {
                                    $_.Exception.Message | Write-Log -Type Err -Evt "(VM:$Vm) $_"
                                }
                            }

                            else {
                                try {
                                    Get-ChildItem -Path $SplitFile | Move-Item -Destination $Backup\$ShortDateNN -ErrorAction 'Stop'
                                }
                                catch {
                                    $_.Exception.Message | Write-Log -Type Err -Evt "(VM:$Vm) $_"
                                }
                            }
                        }
                    }

                    else {
                        $BackupFile = Get-ChildItem -Path ("$WorkDir\$VmFixed-$(Get-DateShort).*") -File
                        $BackupFileN = $BackupFile.name
                        $BackupFileNSplit = $BackupFileN.split(".")

                        $ShortDateT = Test-Path -Path $Backup\$BackupFileN

                        If ($ShortDateT)
                        {
                            Write-Log -Type Info -Evt "(VM:$Vm) File $BackupFileN already exists, appending number"
                            $FileExist = Get-ChildItem -Path $BackupFile -File
                            $i = 1
                            
                            If ($Null -eq $BackupFileNSplit[2])
                            {
                                $ShortDateNN = ("$VmFixed-$(Get-DateShort)-{0:D3}" -f $i++ + $FileExist.Extension)
                                $ShortDateExistT = Test-Path -Path $Backup\$ShortDateNN
                            }
                            else {
                                $ShortDateNN = ("$VmFixed-$(Get-DateShort)-{0:D3}" -f $i++ + "." + $BackupFileNSplit[1] + $FileExist.Extension)
                                $ShortDateExistT = Test-Path -Path $Backup\$ShortDateNN
                            }

                            If ($ShortDateExistT)
                            {
                                If ($Null -eq $BackupFileNSplit[2])
                                {
                                    do {
                                        $ShortDateNN = ("$VmFixed-$(Get-DateShort)-{0:D3}" -f $i++ + $FileExist.Extension)
                                        $ShortDateExistT = Test-Path -Path $Backup\$ShortDateNN
                                    } until ($ShortDateExistT -eq $false)
                                }
                                else {
                                    do {
                                        $ShortDateNN = ("$VmFixed-$(Get-DateShort)-{0:D3}" -f $i++ + "." + $BackupFileNSplit[1] + $FileExist.Extension)
                                        $ShortDateExistT = Test-Path -Path $Backup\$ShortDateNN
                                    } until ($ShortDateExistT -eq $false)
                                }
                            }

                            ## Move with shortdate and appended number
                            try {
                                Get-ChildItem -Path $BackupFile | Move-Item -Destination $Backup\$ShortDateNN -ErrorAction 'Stop'
                            }
                            catch {
                                $_.Exception.Message | Write-Log -Type Err -Evt "(VM:$Vm) $_"
                            }
                        }

                        ## Move with shortdate
                        try {
                            Get-ChildItem -Path $WorkDir -Filter "$VmFixed-*-*-*.*" | Move-Item -Destination $Backup -ErrorAction 'Stop'
                        }
                        catch {
                            $_.Exception.Message | Write-Log -Type Err -Evt "(VM:$Vm) $_"
                        }
                    }
                }

                ## Move with long date
                else {
                    try {
                        Get-ChildItem -Path $WorkDir -Filter "$VmFixed-*-*-*_*-*-*.*" | Move-Item -Destination $Backup -ErrorAction 'Stop'
                    }
                    catch {
                        $_.Exception.Message | Write-Log -Type Err -Evt "(VM:$Vm) $_"
                    }
                }
            }
        }

        ## -Compress switch is NOT configured and the -Keep switch is configured.
        ## Rename the export of each VM to include the date.
        else {
            If ($ShortDate)
            {
                $ShortDateT = Test-Path -Path ("$WorkDir\$VmFixed-$(Get-DateShort)")

                If ($ShortDateT)
                {
                    Write-Log -Type Info -Evt "(VM:$Vm) File $VmFixed-$(Get-DateShort) already exists, appending number"
                    $i = 1
                    $ShortDateNN = ("$VmFixed-$(Get-DateShort)-{0:D3}" -f $i++)
                    $ShortDateExistT = Test-Path -Path $WorkDir\$ShortDateNN

                    If ($ShortDateExistT)
                    {
                        do {
                            $ShortDateNN = ("$VmFixed-$(Get-DateShort)-{0:D3}" -f $i++)
                            $ShortDateExistT = Test-Path -Path $WorkDir\$ShortDateNN
                        } until ($ShortDateExistT -eq $false)
                    }

                    try {
                        Get-ChildItem -Path $WorkDir -Filter $Vm -Directory | Rename-Item -NewName ("$WorkDir\$ShortDateNN")
                    }
                    catch {
                        $_.Exception.Message | Write-Log -Type Err -Evt "(VM:$Vm) $_"
                    }
                }

                try {
                    Get-ChildItem -Path $WorkDir -Filter $Vm -Directory | Rename-Item -NewName ("$WorkDir\$VmFixed-$(Get-DateShort)")
                }
                catch {
                    $_.Exception.Message | Write-Log -Type Err -Evt "(VM:$Vm) $_"
                }
            }

            else {
                try {
                    Get-ChildItem -Path $WorkDir -Filter $Vm -Directory | Rename-Item -NewName ("$WorkDir\$VmFixed-$(Get-DateLong)")
                }
                catch {
                    $_.Exception.Message | Write-Log -Type Err -Evt "(VM:$Vm) $_"
                }
            }

            ## If working directory has been configured by the user, move the backup to the backup folder and rename to include the date.
            If ($WorkDir -ne $Backup)
            {
                ## Make sure the backup directory exists.
                If ((Test-Path -Path $Backup) -eq $False)
                {
                    Write-Log -Type Info -Evt "Backup directory $Backup doesn't exist. Creating it."
                    New-Item $Backup -ItemType Directory -Force | Out-Null
                }

                If ($ShortDate)
                {
                    $ShortDateT = Test-Path -Path ("$Backup\$VmFixed-$(Get-DateShort)")

                    If ($ShortDateT)
                    {
                        Write-Log -Type Info -Evt "(VM:$Vm) File $VmFixed-$(Get-DateShort) already exists, appending number"
                        $i = 1
                        $ShortDateNN = ("$VmFixed-$(Get-DateShort)-{0:D3}" -f $i++)
                        $ShortDateExistT = Test-Path -Path $Backup\$ShortDateNN

                        ## If backup folder already exists with same name, append a number
                        If ($ShortDateExistT)
                        {
                            do {
                                $ShortDateNN = ("$VmFixed-$(Get-DateShort)-{0:D3}" -f $i++)
                                $ShortDateExistT = Test-Path -Path $Backup\$ShortDateNN
                            } until ($ShortDateExistT -eq $false)
                        }

                        ## Moving backup folder with shortdate and append number
                        try {
                            Get-ChildItem -Path $WorkDir -Filter "$VmFixed-*-*-*" -Directory | Move-Item -Destination $Backup\$ShortDateNN -ErrorAction 'Stop'
                        }
                        catch {
                            $_.Exception.Message | Write-Log -Type Err -Evt "(VM:$Vm) $_"
                        }
                    }

                    ## Moving backup folder with shortdate
                    try {
                        Get-ChildItem -Path $WorkDir -Filter "$VmFixed-*-*-*" -Directory | Move-Item -Destination ("$Backup\$VmFixed-$(Get-DateShort)") -ErrorAction 'Stop'
                    }
                    catch {
                        $_.Exception.Message | Write-Log -Type Err -Evt "(VM:$Vm) $_"
                    }
                }

                ## Moving backup folder with longdate
                else {
                    try {
                        Get-ChildItem -Path $WorkDir -Filter "$VmFixed-*-*-*_*-*-*" -Directory | Move-Item -Destination ("$Backup\$VmFixed-$(Get-DateLong)") -ErrorAction 'Stop'
                    }
                    catch {
                        $_.Exception.Message | Write-Log -Type Err -Evt "(VM:$Vm) $_"
                    }
                }
            }
        }
    }
    ##
    ## End of backup Options function
    ##

    ## getting Windows Version info
    $OSVMaj = [environment]::OSVersion.Version | Select-Object -expand major
    $OSVMin = [environment]::OSVersion.Version | Select-Object -expand minor
    $OSVBui = [environment]::OSVersion.Version | Select-Object -expand build
    $OSV = "$OSVMaj" + "." + "$OSVMin" + "." + "$OSVBui"

    If ($Null -eq $BackupUsr)
    {
        Write-Log -Type Err -Evt "You must specify -BackupTo [path\]."
        Exit
    }

    else {
        ## Test for Hyper-V feature installed on local machine.
        try {
            If ($OSV -eq "6.3.9600")
            {
                Get-Service vmms -ErrorAction Stop | Out-Null
            }

            else {
                Get-Service vmcompute -ErrorAction Stop | Out-Null
            }
        }

        catch {
            Write-Log -Type Err -Evt "Hyper-V is not installed on this local machine."
            Exit
        }

        If ($Compress -eq $false -And $Sz -eq $true)
        {
            Write-Log -Type Err -Evt "You must specify -Compress to use -Sz."
            Exit
        }

        If ($Sz -eq $false -And $Null -ne $SzSwitches)
        {
            Write-Log -Type Err -Evt "You must specify -Sz to use -SzOptions."
            Exit
        }

        If ($Null -eq $LogPathUsr -And $Null -ne $LogHistory)
        {
            Write-Log -Type Err -Evt "You must specify -L [path\] to use -LogRotate [number]."
            Exit
        }

        If ($Null -eq $LogPathUsr -And $SmtpServer)
        {
            Write-Log -Type Err -Evt "You must specify -L [path\] to use the email log function."
            Exit
        }

        ## Clean User entered string
        If ($BackupUsr)
        {
            $Backup = $BackupUsr.trimend('\')
        }

        If ($WorkDirUsr)
        {
            $WorkDir = $WorkDirUsr.trimend('\')
        }
    }

    ## Setting an easier to use variable for computer name of the Hyper-V server.
    $Vs = $Env:ComputerName

    ## If a VM list file is configured, get the content of the file, otherwise just get the running VMs.
    ## Clean list if it has empty lines.
    If ($VmList)
    {
        $Vms = Get-Content $VmList | Where-Object {$_.trim() -ne ""}
    }

    else {
        $Vms = Get-VM | Where-Object {$_.State -eq 'Running'} | Select-Object -ExpandProperty Name
    }

    ## Check to see if there are any VMs to process.
    ## If there are no VMs, then do nothing.
    If ($Vms.count -ne 0)
    {
        ## If the user has not configured the working directory, set it as the backup directory.
        If ($Null -eq $WorkDir)
        {
            $WorkDir = "$Backup"
        }

        If ($Null -eq $ShortDate)
        {
            $ShortDate = "$LongDate"
        }

        If ($SzSwitches)
        {
            $SzSwSplit = $SzSwitches.split(",")
        }

        If ($Sz -eq $True)
        {
            $7zT = Test-Path -Path "$env:programfiles\7-Zip\7z.exe"
        }

        ##
        ## Display the current config and log if configured.
        ##
        Write-Log -Type Conf -Evt "************ Running with the following config *************."
        Write-Log -Type Conf -Evt "Utility Version:.........22.06.22"
        Write-Log -Type Conf -Evt "Hostname:................$Vs."
        Write-Log -Type Conf -Evt "Windows Version:.........$OSV."

        If ($Vms)
        {
            Write-Log -Type Conf -Evt "No. of VMs:..............$($Vms.count)."
            Write-Log -Type Conf -Evt "VMs to backup:..........."
            ForEach ($Vm in $Vms)
            {
                Write-Log -Type Conf -Evt ".........................$Vm"
            }
        }

        If ($BackupUsr)
        {
            Write-Log -Type Conf -Evt "Backup directory:........$BackupUsr."
        }

        If ($WorkDirUsr)
        {
            Write-Log -Type Conf -Evt "Working directory:.......$WorkDirUsr."
        }

        If ($NoPerms)
        {
            Write-Log -Type Conf -Evt "-NoPerms switch:.........$NoPerms."
        }

        If ($ShortDate)
        {
            Write-Log -Type Conf -Evt "-ShortDate switch:.......$ShortDate."
        }

        If ($Compress)
        {
            Write-Log -Type Conf -Evt "-Compress switch:........$Compress."
        }

        If ($Sz)
        {
            Write-Log -Type Conf -Evt "-Sz switch:..............$Sz."
        }

        If ($Sz)
        {
            Write-Log -Type Conf -Evt "7-zip installed:.........$7zT."
        }

        If ($SzSwitches)
        {
            Write-Log -Type Conf -Evt "7-zip Options:...........$SzSwitches."
        }

        If ($Null -ne $History)
        {
            Write-Log -Type Conf -Evt "Backups to keep:.........$History days"
        }

        If ($LogPathUsr)
        {
            Write-Log -Type Conf -Evt "Logs directory:..........$LogPathUsr."
        }

        If ($MailTo)
        {
            Write-Log -Type Conf -Evt "E-mail log to:...........$MailTo."
        }

        If ($MailFrom)
        {
            Write-Log -Type Conf -Evt "E-mail log from:.........$MailFrom."
        }

        If ($MailSubject)
        {
            Write-Log -Type Conf -Evt "E-mail subject:..........$MailSubject."
        }

        If ($SmtpServer)
        {
            Write-Log -Type Conf -Evt "SMTP server:.............$SmtpServer."
        }

        If ($SmtpPort)
        {
            Write-Log -Type Conf -Evt "SMTP Port:...............$SmtpPort."
        }

        If ($SmtpUser)
        {
            Write-Log -Type Conf -Evt "SMTP user:...............$SmtpUser."
        }

        If ($SmtpPwd)
        {
            Write-Log -Type Conf -Evt "SMTP pwd file:...........$SmtpPwd."
        }

        If ($SmtpServer)
        {
            Write-Log -Type Conf -Evt "-UseSSL switch:..........$UseSsl."
        }
        Write-Log -Type Conf -Evt "************************************************************"
        Write-Log -Type Info -Evt "Process started."
        ##
        ## Display current config ends here.
        ##

        ## For Success/Fail stats
        $Succi = 0
        $Faili = 0

        ##
        ## -NoPerms process starts here.
        ##
        ## If the -NoPerms switch is set, start a custom process to copy all the VM data.
        If ($NoPerms)
        {
            ForEach ($Vm in $Vms)
            {
                $VmInfo = Get-VM -Name $Vm
                $BackupSucc = $false

                ## Test for the existence of a previous VM export. If it exists, delete it.
                If (Test-Path -Path "$WorkDir\$Vm")
                {
                    Remove-Item "$WorkDir\$Vm" -Recurse -Force
                }

                ## Create directories for the VM export.
                try {
                    New-Item "$WorkDir\$Vm" -ItemType Directory -Force | Out-Null
                    New-Item "$WorkDir\$Vm\Virtual Machines" -ItemType Directory -Force | Out-Null
                    New-Item "$WorkDir\$Vm\Virtual Hard Disks" -ItemType Directory -Force | Out-Null
                    New-Item "$WorkDir\$Vm\Snapshots" -ItemType Directory -Force | Out-Null
                    $BackupSucc = $true
                }
                catch {
                    $_.Exception.Message | Write-Log -Type Err -Evt "(VM:$Vm) $_"
                    $BackupSucc = $false
                }

                ## Check for VM running
                If (Get-VM | Where-Object {$_.State -eq 'Running'})
                {
                    $VMwasRunning = $true
                    Write-Log -Type Info -Evt "(VM:$Vm) Stopping VM"
                    Stop-VM -Name $Vm
                }

                else {
                    $VMwasRunning = $false
                    Write-Log -Type Err -Evt "(VM:$Vm) VM not running"
                }

                ##
                ## Copy the VM config files and log if there is an error.
                ##
                ## Check for VM being in the correct state before continuing

                $VmState = Get-Vm -Name $Vm

                If ($VmState.State -ne 'Off' -OR $VmState.State -ne 'Saved' -AND $VmState.Status -ne 'Operating normally')
                {
                    do {
                        Write-Log -Type Err -Evt "(VM:$Vm) VM not in the desired state. Waiting 60 seconds..."
                        Start-Sleep -S 60
                    } until ($VmState.State -eq 'Off' -OR $VmState.State -eq 'Saved' -AND $VmState.Status -eq 'Operating normally')
                }

                try {
                    $BackupSucc = $false
                    Write-Log -Type Info -Evt "(VM:$Vm) Copying config files"
                    Copy-Item "$($VmInfo.ConfigurationLocation)\Virtual Machines\$($VmInfo.id)" "$WorkDir\$Vm\Virtual Machines\" -Recurse -Force
                    Copy-Item "$($VmInfo.ConfigurationLocation)\Virtual Machines\$($VmInfo.id).*" "$WorkDir\$Vm\Virtual Machines\" -Recurse -Force
                    $BackupSucc = $true
                }
                catch {
                    $_.Exception.Message | Write-Log -Type Err -Evt "(VM:$Vm) $_"
                    $BackupSucc = $false
                }
                ##
                ## End of VM config files.
                ##

                ##
                ## Copy the VHDs and log if there is an error.
                ##
                try {
                    $BackupSucc = $false
                    Write-Log -Type Info -Evt "(VM:$Vm) Copying VHD files"
                    Copy-Item $VmInfo.HardDrives.Path -Destination "$WorkDir\$Vm\Virtual Hard Disks\" -Recurse -Force
                    $BackupSucc = $true
                }
                catch {
                    $_.Exception.Message | Write-Log -Type Err -Evt "(VM:$Vm) $_"
                    $BackupSucc = $false
                }
                ##
                ## End of VHDs.
                ##

                ## Get the VM snapshots/checkpoints.
                $Snaps = Get-VMSnapshot $Vm

                ForEach ($Snap in $Snaps)
                {
                    ##
                    ## Copy the snapshot config files and log if there is an error.
                    ##
                    try {
                        $BackupSucc = $false
                        Write-Log -Type Info -Evt "(VM:$Vm) Copying Snapshot config files"
                        Copy-Item "$($VmInfo.ConfigurationLocation)\Snapshots\$($Snap.id)" "$WorkDir\$Vm\Snapshots\" -Recurse -Force
                        Copy-Item "$($VmInfo.ConfigurationLocation)\Snapshots\$($Snap.id).*" "$WorkDir\$Vm\Snapshots\" -Recurse -Force
                        $BackupSucc = $true
                    }
                    catch {
                        $_.Exception.Message | Write-Log -Type Err -Evt "(VM:$Vm) $_"
                        $BackupSucc = $false
                    }
                    ##
                    ## End of snapshot config.
                    ##

                    ## Copy the snapshot root VHD.
                    try {
                        $BackupSucc = $false
                        Write-Log -Type Info -Evt "(VM:$Vm) Copying Snapshot root VHD files"
                        Copy-Item $Snap.HardDrives.Path -Destination "$WorkDir\$Vm\Virtual Hard Disks\" -Recurse -Force -ErrorAction 'Stop'
                        $BackupSucc = $true
                    }
                    catch {
                        $_.Exception.Message | Write-Log -Type Err -Evt "(VM:$Vm) $_"
                        $BackupSucc = $false
                    }
                }

                If ($VMwasRunning)
                {
                    Write-Log -Type Info -Evt "(VM:$Vm) Starting VM"
                    Start-VM $Vm
                }

                If ($BackupSucc)
                {
                    Start-Sleep -S 60
                    OptionsRun
                    Write-Log -Type Info -Evt "(VM:$Vm) Backup Successful"
                    $Succi = $Succi+1
                }

                else {
                    Write-Log -Type Err -Evt "(VM:$Vm) Backup failed, VM skipped"
                    $Faili = $Faili+1
                    Start-Sleep -S 60
                }
            }
        }
        ##
        ## -NoPerms process ends here.
        ##

        ##
        ## Standard export process starts here.
        ##
        ## If the -NoPerms switch is NOT set, for each VM check for the existence of a previous export.
        ## If it exists then delete it, otherwise the export will fail.
        else {
            ForEach ($Vm in $Vms)
            {
                If (Test-Path -Path "$WorkDir\$Vm")
                {
                    Remove-Item "$WorkDir\$Vm" -Recurse -Force
                }

                If ($WorkDir -ne $Backup)
                {
                    If (Test-Path -Path "$Backup\$Vm")
                    {
                        Remove-Item "$Backup\$Vm" -Recurse -Force
                    }
                }
            }

            ## If default key is already null, then disable VSS Legacy Tracing on Windows Server 2016 to prevent possible BSOD on Hyper-V Host.
            ## Don't want to mess up anyone's config. :)
            If ($OSV -eq "10.0.14393")
            {
                If ($null -eq (get-ItemProperty -literalPath HKLM:\System\CurrentControlSet\Services\VSS\Diag\).'(Default)')
                {
                    $RegVSSFix = $True
                    Set-ItemProperty -Path HKLM:\System\CurrentControlSet\Services\VSS\Diag -Name "(default)" -Value "Disabled"
                    Write-Log -Type Info -Evt "Disabling VSS Legacy Tracing on Windows Server 2016 to prevent possible BSOD on Hyper-V Host."
                }
            }

            ## Do a regular export of the VMs.
            ForEach ($Vm in $Vms)
            {
                $BackupSucc = $false

                try {
                    Write-Log -Type Info -Evt "(VM:$Vm) Attempting to export VM"
                    $Vm | Export-VM -Path "$WorkDir" -ErrorAction 'Stop'
                    $BackupSucc = $true
                }
                catch {
                    $_.Exception.Message | Write-Log -Type Err -Evt "(VM:$Vm) $_"
                    $BackupSucc = $false
                }

                If ($BackupSucc)
                {
                    OptionsRun
                    Write-Log -Type Info -Evt "(VM:$Vm) Backup Successful"
                    $Succi = $Succi+1
                }

                else {
                    Write-Log -Type Err -Evt "(VM:$Vm) Export failed, VM skipped"
                    $Faili = $Faili+1
                }
            }

            ## If the VSS fix was run, return regkey back to original state.
            If ($OSV -eq "10.0.14393")
            {
                If ($RegVSSFix)
                {
                    REG DELETE "HKEY_LOCAL_MACHINE\System\CurrentControlSet\Services\VSS\Diag" /ve /f
                    Write-Log -Type Info -Evt "Returning VSS Legacy Tracing config to default."
                }
            }
        }
        ##
        ## End of standard export
        ##
    }

    ## If there are no VMs running, then do nothing.
    else {
        Write-Log -Type Err -Evt "There are no VMs running to backup"
    }

    Write-Log -Type Info -Evt "Process finished."
    Write-Log -Type Info -Evt "Number of VMs to Backup:$($Vms.count)"
    Write-Log -Type Info -Evt "Backups Successful:$Succi"
    Write-Log -Type Info -Evt "Backups Failed:$Faili"

    If ($Null -ne $LogHistory)
    {
        ## Cleanup logs.
        Write-Log -Type Info -Evt "Deleting logs older than: $LogHistory days"
        Get-ChildItem -Path "$LogPath\Hyper-V-Backup_*" -File | Where-Object CreationTime -lt (Get-Date).AddDays(-$LogHistory) | Remove-Item -Recurse
    }

    ## This whole block is for e-mail, if it is configured.
    If ($SmtpServer)
    {
        If (Test-Path -Path $Log)
        {
            ## Default e-mail subject if none is configured.
            If ($Null -eq $MailSubject)
            {
                $MailSubject = "Hyper-V Backup Utility Log"
            }

            ## Default Smtp Port if none is configured.
            If ($Null -eq $SmtpPort)
            {
                $SmtpPort = "25"
            }

            ## Setting the contents of the log to be the e-mail body.
            $MailBody = Get-Content -Path $Log | Out-String

            ForEach ($MailAddress in $MailTo)
            {
                ## If an smtp password is configured, get the username and password together for authentication.
                ## If an smtp password is not provided then send the e-mail without authentication and obviously no SSL.
                If ($SmtpPwd)
                {
                    $SmtpPwdEncrypt = Get-Content $SmtpPwd | ConvertTo-SecureString
                    $SmtpCreds = New-Object System.Management.Automation.PSCredential -ArgumentList ($SmtpUser, $SmtpPwdEncrypt)

                    ## If -ssl switch is used, send the email with SSL.
                    ## If it isn't then don't use SSL, but still authenticate with the credentials.
                    If ($UseSsl)
                    {
                        Send-MailMessage -To $MailAddress -From $MailFrom -Subject "$MailSubject $Succi/$($Vms.count) VMs Successful" -Body $MailBody -SmtpServer $SmtpServer -Port $SmtpPort -UseSsl -Credential $SmtpCreds
                    }

                    else {
                        Send-MailMessage -To $MailAddress -From $MailFrom -Subject "$MailSubject $Succi/$($Vms.count) VMs Successful" -Body $MailBody -SmtpServer $SmtpServer -Port $SmtpPort -Credential $SmtpCreds
                    }
                }

                else {
                    Send-MailMessage -To $MailAddress -From $MailFrom -Subject "$MailSubject $Succi/$($Vms.count) VMs Successful" -Body $MailBody -SmtpServer $SmtpServer -Port $SmtpPort
                }
            }
        }

        else {
            Write-Host -ForegroundColor Red -BackgroundColor Black -Object "There's no log file to email."
        }
    }
    ## End of Email block
}
## End