<#PSScriptInfo

.VERSION 24.03.18

.GUID c7fb05cc-1e20-4277-9986-523020060668

.AUTHOR Mike Galvin Contact: mike@gal.vin

.COMPANYNAME Mike Galvin

.COPYRIGHT (C) Mike Galvin. All rights reserved.

.TAGS Hyper-V Virtual Machines Full Backup Export Permissions Zip History 7-Zip

.LICENSEURI

.PROJECTURI https://gal.vin/utils/hyperv-backup-utility/

.ICONURI

.EXTERNALMODULEDEPENDENCIES

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
    [Alias("Webhook")]
    [ValidateScript({Test-Path -Path $_ -PathType Leaf})]
    [string]$Webh,
    [switch]$UseSsl,
    [switch]$NoPerms,
    [switch]$Compress,
    [switch]$Sz,
    [switch]$ShortDate,
    [switch]$Help,
    [switch]$LowDisk,
    [switch]$ProgCheck,
    [switch]$OptimiseVHD,
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
                              Mike Galvin   https://gal.vin                     Version 24.03.18              
                         Donate: https://www.paypal.me/digressive             See -help for usage             
"
}

If ($PSBoundParameters.Values.Count -eq 0 -or $Help)
{
    Write-Host -Object " Usage:
    From a terminal run: [path\]Hyper-V-Backup.ps1 -BackupTo [path\]
    This will backup all the VMs running to the backup location specified.

    Use -List [path\]vms.txt to specify a list of vm names to backup.
    Use -Wd [path\] to configure a working directory for the backup process.
    Use -Keep [number] to specify how many days worth of backup to keep.
    Use -ShortDate to use only the Year, Month and Day in backup filenames.
    Use -LowDisk to remove old backups before new ones are created. For low disk space situations.
    Use -ProgCheck to send notifications (email or webhook) after each VM is backed up.
    Use -OptimiseVHD to optimise the VHDs and make them smaller before copy. Must be used with -NoPerms option.

    -NoPerms should only be used when a regular backup cannot be performed.
    Please note: this will cause the VMs to shutdown during the backup process.

    Use -Compress to compress the VM backups in a zip file using Windows compression.
    Use -Sz to use 7-zip 
    Use -SzOptions ""'-t7z,-v2g,-ppassword'"" to specify 7-zip options like file type, split files or password.

    To output a log: -L [path\].
    To remove logs produced by the utility older than X days: -LogRotate [number].
    Run with no ASCII banner: -NoBanner

    To send the log to a webhook on job completion:
    Specify a txt file containing the webhook URI with -Webhook [path\]webhook.txt

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
    Function Get-DateFormat()
    {
        Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }

    Function Get-DateShort()
    {
        Get-Date -Format "yyyy-MM-dd"
    }

    Function Get-DateLong()
    {
        Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    }

    ## Function for logging.
    Function Write-Log($Type,$Evt)
    {
        If ($Type -eq "Info")
        {
            If ($LogPathUsr)
            {
                Add-Content -Path $Log -Encoding ASCII -Value "$(Get-DateFormat) [INFO] $Evt"
            }

            Write-Host -Object " $(Get-DateFormat) [INFO] $Evt"
        }

        If ($Type -eq "Succ")
        {
            If ($LogPathUsr)
            {
                Add-Content -Path $Log -Encoding ASCII -Value "$(Get-DateFormat) [SUCCESS] $Evt"
            }

            Write-Host -ForegroundColor Green -Object " $(Get-DateFormat) [SUCCESS] $Evt"
        }

        If ($Type -eq "Err")
        {
            If ($LogPathUsr)
            {
                Add-Content -Path $Log -Encoding ASCII -Value "$(Get-DateFormat) [ERROR] $Evt"
            }

            Write-Host -ForegroundColor Red -BackgroundColor Black -Object " $(Get-DateFormat) [ERROR] $Evt"
        }

        If ($Type -eq "Conf")
        {
            If ($LogPathUsr)
            {
                Add-Content -Path $Log -Encoding ASCII -Value "$Evt"
            }

            Write-Host -ForegroundColor Cyan -Object " $Evt"
        }
    }

    ## Function to optimise the VHD
    Function OptimVHD()
    {
        try {
            Write-Log -Type Info -Evt "(VM:$Vm) Optimising VHD(s)"
            $VmVhds = Get-VHD -Path $($Vm | Get-VMHardDiskDrive | Select-Object -ExpandProperty "Path")

            ## Loop through each VHD file and optimise
            ForEach ($Vhd in $VmVhds) {
                Write-Log -Type Info -Evt "(VM:$Vm) Used space before optimising VHD [$($Vhd.Path)] = $([math]::ceiling((Get-VHD -Path $Vhd.Path).FileSize / 1GB )) GB"
                Optimize-VHD -Path "$($Vhd.Path)" -Mode Full
                Write-Log -Type Info -Evt "(VM:$Vm) Used space after optimising VHD [$($Vhd.Path)] = $([math]::ceiling((Get-VHD -Path $Vhd.Path).FileSize / 1GB )) GB"
                $intTotalDisksSize += (Get-VHD -Path $Vhd.Path).FileSize
            }

            Write-Log -Type Info -Evt "(VM:$Vm) Done optimising VHD(s)"
        }

        catch {
            $_.Exception.Message | Write-Log -Type Err -Evt "(VM:$Vm) $_"
        }
    }

    ## Function for Notifications
    Function Notify()
    {
        ## This whole block is for "simple auth" e-mail, if it is configured.
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
                        $SmtpCreds = New-Object System.Management.Automation.PSCredential -ArgumentList $SmtpUser, $($SmtpPwd | ConvertTo-SecureString -AsPlainText -Force)

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

        ## Webhook block
        If ($Webh)
        {
            $WebHookUri = Get-Content $Webh
            $WebHookArr = @()

            $title       = "Hyper-V Backup Utility $Succi/$($Vms.count) VMs Successful"
            $description = Get-Content -Path $Log | Out-String

            $WebHookObj = [PSCustomObject]@{
                title = $title
                description = $description
            }

            $WebHookArr += $WebHookObj
            $payload = [PSCustomObject]@{
                embeds = $WebHookArr
            }

            Invoke-RestMethod -Uri $WebHookUri -Body ($payload | ConvertTo-Json -Depth 2) -Method Post -ContentType 'application/json'
        }
    }

    ## Function for Update Check
    Function UpdateCheck()
    {
        $ScriptVersion = "24.03.18"
        $RawSource = "https://raw.githubusercontent.com/Digressive/HyperV-Backup-Utility/master/Hyper-V-Backup.ps1"

        try {
            $SourceCheck = Invoke-RestMethod -uri "$RawSource"
            $VerCheck = $SourceCheck -split '\n' | Select-String -Pattern ".VERSION $ScriptVersion" -SimpleMatch -CaseSensitive -Quiet

            If ($VerCheck -ne $True)
            {
                Write-Log -Type Conf -Evt "-- There is an update available! --"
            }
        }

        catch {
        }
    }

    ##
    ## Start of backup Options functions
    ##

    Function CompressFiles7zip($CompressDateFormat,$CompressDir,$CompressFileName)
    {
        $7zipOutput = $null
        $7zipTestOutput = $null
        $CompressFileNameSet = $CompressFileName+$CompressDateFormat

        ## Makeshift error catch for 7zip in PowerShell
        $7zipOutput = & "$env:programfiles\7-Zip\7z.exe" $SzSwSplit -bso0 a ("$CompressDir\$CompressFileNameSet") "$CompressDir\$Vm\*" *>&1

        If ($7zipOutput -match "ERROR:")
        {
            Write-Log -Type Err -Evt "(VM:$Vm) 7zip encountered an error creating the archive"
            Set-Variable -Name 'BackupSucc' -Value $false -Scope 2
        }

        else {
            Set-Variable -Name 'BackupSucc' -Value $true -Scope 2
        }

        $GetTheFile = Get-ChildItem -Path $CompressDir -File -Filter "$CompressFileNameSet.*"

        $archivePassword = if ($null -ne $SzSwitches)
        {
            $password = ($SzSwitches -split ',') | Where-Object { $_ -match '^-p(.*)' } | ForEach-Object { $matches[1] }
            if ($password -ne "" -and $null -ne  $password)
            {
                "-p$password"
            }
            else {""}
        }
        else {""}

        $7zipTestOutput = & "$env:programfiles\7-Zip\7z.exe" $archivePassword -bso0 t $($GetTheFile.FullName) *>&1

        If ($7zipTestOutput -match "ERROR:")
        {
            Write-Log -Type Err -Evt "(VM:$Vm) 7zip encountered an error verifying the archive"
            Set-Variable -Name 'BackupSucc' -Value $false -Scope 2
        }

        else {
            Set-Variable -Name 'BackupSucc' -Value $true -Scope 2
        }
    }

    Function CompressFilesWin($CompressDateFormat,$CompressDir,$CompressFileName)
    {
        Add-Type -AssemblyName "system.io.compression.filesystem"

        $CompressFileNameSet = $CompressFileName+$CompressDateFormat
        ## Windows compression with shortdate
        try {
            [io.compression.zipfile]::CreateFromDirectory("$CompressDir\$Vm", ("$CompressDir\$CompressFileNameSet.zip"))
            Set-Variable -Name 'BackupSucc' -Value $true -Scope 2
        }
        catch {
            $_.Exception.Message | Write-Log -Type Err -Evt "(VM:$Vm) $_"
            Set-Variable -Name 'BackupSucc' -Value $false -Scope 2
        }
    }

    Function ShortDateFileNo($ShortDateDir,$ShortDateFilePat)
    {
        Write-Log -Type Info -Evt "(VM:$Vm) Backup $VmFixed-$(Get-DateShort) already exists, appending number"
        $i = 1
        $ShortDateNN = ("$VmFixed-$(Get-DateShort)-{0:D3}" -f $i++)+$ShortDateFilePat
        $ShortDateExistT = Test-Path -Path $ShortDateDir\$ShortDateNN

        If ($ShortDateExistT)
        {
            do {
                $ShortDateNN = ("$VmFixed-$(Get-DateShort)-{0:D3}" -f $i++)+$ShortDateFilePat
                $ShortDateExistT = Test-Path -Path $ShortDateDir\$ShortDateNN
            } until ($ShortDateExistT -eq $false)
        }

        If ($Compress)
        {
            If ($Sz -eq $True -AND $7zT -eq $True)
            {
                If ($SzSwSplit -like "-v*")
                {
                    ## 7-zip compression with shortdate configured and a number appended.
                    $ShortDateNN7zFix = $ShortDateNN -replace '[.*]'
                    CompressFiles7zip -CompressDir $ShortDateDir -CompressFileName $ShortDateNN7zFix
                }
                
                else {
                    ## 7-zip compression with shortdate configured and a number appended.
                    $ShortDateNN7zFix = $ShortDateNN -replace '[.*]'
                    CompressFiles7zip -CompressDir $ShortDateDir -CompressFileName $ShortDateNN7zFix
                }
            }

            else {
                ## Windows compression with shortdate configured and a number appended.
                $ShortDateNNWinFix = $ShortDateNN.TrimEnd(".zip")
                CompressFilesWin -CompressDir $ShortDateDir -CompressFileName $ShortDateNNWinFix
            }
        }

        else {
            try {
                Get-ChildItem -Path $ShortDateDir -Filter $Vm -Directory | Rename-Item -NewName ("$ShortDateDir\$ShortDateNN")
            }
            catch {
                $_.Exception.Message | Write-Log -Type Err -Evt "(VM:$Vm) $_"
            }

            If ($WorkDir -ne $Backup)
            {
                ## Moving backup folder with shortdate and renaming with number appended.
                try {
                    Get-ChildItem -Path $WorkDir -Filter "$VmFixed-*-*-*" -Directory | Move-Item -Destination $ShortDateDir\$ShortDateNN -ErrorAction 'Stop'
                }
                catch {
                    $_.Exception.Message | Write-Log -Type Err -Evt "(VM:$Vm) $_"
                }
            }
        }
    }

    Function ReportRemove($RemoveDir,$RemoveFilePat,$RemoveDirOpt,$RemoveHistory)
    {
        If ($RemoveDirOpt)
        {
            $RemoveDirOptSet = @{Directory = $true}
        }

        else {
            $RemoveDirOptSet = @{Directory = $false}
        }

        $RemoveFullPath = $VmFixed+$RemoveFilePat

        ## report old files to remove
        If ($LogPathUsr)
        {
            If (Test-Path -Path $RemoveDir)
            {
                Get-ChildItem -Path $RemoveDir -Filter $RemoveFullPath @RemoveDirOptSet | Where-Object CreationTime -lt (Get-Date).AddDays(-$RemoveHistory) | Select-Object -Property Name, CreationTime | Format-Table -HideTableHeaders | Out-File -Append $Log -Encoding ASCII
            }
        }

        ## remove old files
        If (Test-Path -Path $RemoveDir)
        {
            Get-ChildItem -Path $RemoveDir -Filter $RemoveFullPath @RemoveDirOptSet | Where-Object CreationTime -lt (Get-Date).AddDays(-$RemoveHistory) | Remove-Item -Recurse -Force
        }
    }

    Function RemoveOld()
    {
        ## Remove previous backup folders. -Keep switch and -Compress switch are NOT configured.
        If ($Null -eq $History -And $Compress -eq $False)
        {
            Write-Log -Type Info -Evt "(VM:$Vm) Removing previous backups"
            ## Remove all previous backup folders
            If ($ShortDate)
            {
                ReportRemove -RemoveDir $WorkDir -RemoveFilePat "-*-*-*" -RemoveDirOpt $true -RemoveHistory $null
            }

            else {
                ReportRemove -RemoveDir $WorkDir -RemoveFilePat "-*-*-*_*-*-*" -RemoveDirOpt $true -RemoveHistory $null
            }

            ## If working directory is configured by user, remove all previous backup folders
            If ($WorkDir -ne $Backup)
            {
                ## Make sure the backup directory exists.
                If (Test-Path -Path $Backup)
                {
                    If ($ShortDate)
                    {
                        ReportRemove -RemoveDir $Backup -RemoveFilePat "-*-*-*" -RemoveDirOpt $true -RemoveHistory $null
                    }

                    else {
                        ReportRemove -RemoveDir $Backup -RemoveFilePat "-*-*-*_*-*-*" -RemoveDirOpt $true -RemoveHistory $null
                    }
                }
            }
        }

        ## Remove previous backup folders older than X configured days. -Keep switch is configured and -Compress switch is NOT.
        else {
            If ($Compress -eq $False)
            {
                Write-Log -Type Info -Evt "(VM:$Vm) Removing backup folders older than: $History days"

                ## Remove previous backup folders older than the configured number of days.
                If ($ShortDate)
                {
                    ReportRemove -RemoveDir $WorkDir -RemoveFilePat "-*-*-*" -RemoveDirOpt $true -RemoveHistory $History
                }

                else {
                    ReportRemove -RemoveDir $WorkDir -RemoveFilePat "-*-*-*_*-*-*" -RemoveDirOpt $true -RemoveHistory $History
                }

                ## If working directory is configured by user, remove all previous backup folders older than X configured days.
                If ($WorkDir -ne $Backup)
                {
                    ## Make sure the backup directory exists.
                    If (Test-Path -Path $Backup)
                    {
                        If ($ShortDate)
                        {
                            ReportRemove -RemoveDir $Backup -RemoveFilePat "-*-*-*" -RemoveDirOpt $true -RemoveHistory $History
                        }

                        else {
                            ReportRemove -RemoveDir $Backup -RemoveFilePat "-*-*-*_*-*-*" -RemoveDirOpt $true -RemoveHistory $History
                        }
                    }
                }
            }
        }

        ## Remove ALL previous backup files. -Keep switch is NOT configured and -Compress switch IS.
        If ($Compress)
        {
            If ($Null -eq $History)
            {
                Write-Log -Type Info -Evt "(VM:$Vm) Removing all previous compressed backups"

                ## Remove all previous compressed backups
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

                ## Remove previous compressed backups older than the configured number of days.
                If ($ShortDate)
                {
                    ReportRemove -RemoveDir $WorkDir -RemoveFilePat "-*-*-*.*" -RemoveDirOpt $false -RemoveHistory $History
                }

                else {
                    ReportRemove -RemoveDir $WorkDir -RemoveFilePat "-*-*-*_*-*-*.*" -RemoveDirOpt $false -RemoveHistory $History
                }

                ## If working directory is configured by user, remove previous backup files older than X days.
                If ($WorkDir -ne $Backup)
                {
                    ## Make sure the backup directory exists.
                    If (Test-Path -Path $Backup)
                    {
                        If ($ShortDate)
                        {
                            ReportRemove -RemoveDir $Backup -RemoveFilePat "-*-*-*.*" -RemoveDirOpt $false -RemoveHistory $History
                        }

                        else {
                            ReportRemove -RemoveDir $Backup -RemoveFilePat "-*-*-*_*-*-*.*" -RemoveDirOpt $false -RemoveHistory $History
                        }
                    }
                }
            }
        }
    }

    Function OptionsRun()
    {
        If ($Compress)
        {
            ## If -Compress and -Sz are configured AND 7-zip is installed - compress the backup folder, if it isn't fallback to Windows compression.
            If ($Sz -eq $True -AND $7zT -eq $True)
            {
                Write-Log -Type Info -Evt "(VM:$Vm) Compressing backup using 7-Zip compression"

                ## If -Shortdate is configured, test for an old backup file, if true append a number (and increase the number if file still exists) before the file extension.
                If ($ShortDate)
                {
                    ## If using 7zip's split file feature with short dates, we need to handle the files a little differently.
                    If ($SzSwSplit -like "-v*")
                    {
                        $ShortDateT = Test-Path -Path ("$WorkDir\$VmFixed-$(Get-DateShort).*.*")

                        If ($ShortDateT)
                        {
                            ShortDateFileNo -ShortDateDir $WorkDir -ShortDateFilePat ".*.*"
                        }

                        else {
                            CompressFiles7zip(Get-DateShort) -CompressDir $WorkDir -CompressFileName "$VmFixed-$CompressDateFormat"
                        }
                    }

                    else
                    {
                        $ShortDateT = Test-Path -Path ("$WorkDir\$VmFixed-$(Get-DateShort).*")

                        If ($ShortDateT)
                        {
                            ShortDateFileNo -ShortDateDir $WorkDir -ShortDateFilePat ".*"
                        }

                        CompressFiles7zip(Get-DateShort) -CompressDir $WorkDir -CompressFileName "$VmFixed-$CompressDateFormat"
                    }
                }

                else {
                    CompressFiles7zip(Get-DateLong) -CompressDir $WorkDir -CompressFileName "$VmFixed-$CompressDateFormat"
                }
            }

            ## Compress the backup folder using Windows compression. -Compress is configured, -Sz switch is not, or it is and 7-zip isn't detected.
            ## This is also the "fallback" windows compression code.
            else {
                Write-Log -Type Info -Evt "(VM:$Vm) Compressing backup using Windows compression"

                If ($ShortDate)
                {
                    $ShortDateT = Test-Path -Path ("$WorkDir\$VmFixed-$(Get-DateShort).zip")

                    If ($ShortDateT)
                    {
                        ShortDateFileNo -ShortDateDir $WorkDir -ShortDateFilePat ".zip"
                    }

                    else {
                        CompressFilesWin(Get-DateShort) -CompressDir $WorkDir -CompressFileName "$VmFixed-$CompressDateFormat"
                    }
                }

                else {
                    CompressFilesWin(Get-DateLong) -CompressDir $WorkDir -CompressFileName "$VmFixed-$CompressDateFormat"
                }
            }

            ## After being compressed, if success remove the VMs export folder.
            If ($BackupSucc)
            {
                Get-ChildItem -Path $WorkDir -Filter "$Vm" -Directory | Remove-Item -Recurse -Force
            }

            else {
                Write-Log -Type Err -Evt "(VM:$Vm) Compressing backup failed."
                Set-Variable -Name 'BackupSucc' -Value $false -Scope 1
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
                ## This contains special code to do the shortDate renaming with any 7-zip split files.
                If ($ShortDate)
                {
                    If ($SzSwSplit -like "-v*")
                    {
                        $SzSplitFiles = Get-ChildItem -Path ("$WorkDir\$VmFixed-$(Get-DateShort).*.*") -File

                        ForEach ($SplitFile in $SzSplitFiles) {
                            $ShortDateT = Test-Path -Path "$Backup\$($SplitFile.name)"
                            $split7zArray = $SplitFile.basename.Split(".")
                            $archType = $split7zArray[1]

                            If ($ShortDateT)
                            {
                                Write-Log -Type Info -Evt "(VM:$Vm) File: $($SplitFile.name) already exists, appending number"
                                $FileExist = Get-ChildItem -Path "$Backup\$($SplitFile.name)" -File
                                $i = 1

                                $ShortDateNN = ("$VmFixed-$(Get-DateShort)-{0:D3}" -f $i++ + "." + $archType + $FileExist.Extension)
                                $ShortDateExistT = Test-Path -Path $Backup\$ShortDateNN

                                If ($ShortDateExistT)
                                {
                                    do {
                                        $ShortDateNN = ("$VmFixed-$(Get-DateShort)-{0:D3}" -f $i++ + "." + $archType + $FileExist.Extension)
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
                            Write-Log -Type Info -Evt "(VM:$Vm) File: $BackupFileN already exists, appending number"
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
                    ShortDateFileNo -ShortDateDir $WorkDir -ShortDateFilePat $null
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
                        ShortDateFileNo -ShortDateDir $Backup -ShortDateFilePat $null
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
    ## End of backup Options functions
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
        ## Old version of Win Serv have a different service name.
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

        If ($Null -eq $LogPathUsr -And $Webh)
        {
            Write-Log -Type Err -Evt "You must specify -L [path\] to use send the log to a webhook."
            Exit
        }

        If ($NoPerms -eq $false -And $OptimiseVHD -eq $true)
        {
            Write-Log -Type Err -Evt "You must specify -NoPerms to use -OptimiseVHD."
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
        Write-Log -Type Conf -Evt "--- Running with the following config ---"
        Write-Log -Type Conf -Evt "Utility Version: 24.03.18"
        UpdateCheck ## Run Update checker function
        Write-Log -Type Conf -Evt "Hostname: $Vs."
        Write-Log -Type Conf -Evt "Windows Version: $OSV."

        If ($Vms)
        {
            Write-Log -Type Conf -Evt "No. of VMs: $($Vms.count)."
            Write-Log -Type Conf -Evt "VMs to backup:"
            ForEach ($Vm in $Vms)
            {
                Write-Log -Type Conf -Evt "$Vm"
            }
        }

        If ($BackupUsr)
        {
            Write-Log -Type Conf -Evt "Backup directory: $BackupUsr."
        }

        If ($WorkDirUsr)
        {
            Write-Log -Type Conf -Evt "Working directory: $WorkDirUsr."
        }

        If ($NoPerms)
        {
            Write-Log -Type Conf -Evt "-NoPerms switch: $NoPerms."
        }

        If ($ShortDate)
        {
            Write-Log -Type Conf -Evt "-ShortDate switch: $ShortDate."
        }

        If ($LowDisk)
        {
            Write-Log -Type Conf -Evt "-LowDisk switch: $LowDisk."
        }

        If ($Compress)
        {
            Write-Log -Type Conf -Evt "-Compress switch: $Compress."
        }

        If ($Sz)
        {
            Write-Log -Type Conf -Evt "-Sz switch: $Sz."
        }

        If ($Sz)
        {
            Write-Log -Type Conf -Evt "7-zip installed: $7zT."
        }

        If ($SzSwitches)
        {
            Write-Log -Type Conf -Evt "7-zip Options: $SzSwitches."
        }

        If ($Null -ne $History)
        {
            Write-Log -Type Conf -Evt "Backups to keep: $History days"
        }

        If ($LogPathUsr)
        {
            Write-Log -Type Conf -Evt "Logs directory: $LogPathUsr."
        }

        If ($Webh)
        {
            Write-Log -Type Conf -Evt "Webhook: Configured"
        }

        If ($MailTo)
        {
            Write-Log -Type Conf -Evt "E-mail log to: $MailTo."
        }

        If ($MailFrom)
        {
            Write-Log -Type Conf -Evt "E-mail log from: $MailFrom."
        }

        If ($MailSubject)
        {
            Write-Log -Type Conf -Evt "E-mail subject: $MailSubject."
        }

        If ($SmtpServer)
        {
            Write-Log -Type Conf -Evt "SMTP server: Configured"
        }

        If ($SmtpUser)
        {
            Write-Log -Type Conf -Evt "SMTP auth: Configured"
        }
        Write-Log -Type Conf -Evt "---"
        Write-Log -Type Info -Evt "Process started"
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
                ## Get VM info
                try {
                    $VhdSize = Get-VHD -Path $($Vm | Get-VMHardDiskDrive | Select-Object -ExpandProperty "Path") | Select-Object @{Name = "FileSizeGB"; Expression = {[math]::ceiling($_.FileSize/1GB)}}, @{Name = "MaxSizeGB"; Expression = {[math]::ceiling($_.Size/1GB)}}
                    Write-Log -Type Info -Evt "(VM:$Vm) has [$((Get-VMProcessor $Vm).Count)] CPU cores, [$([math]::ceiling((Get-VMMemory $Vm).Startup / 1gb))GB] RAM, Storage: [Current Size = $($VhdSize.FileSizeGB)GB - Max Size = $($VhdSize.MaxSizeGB)GB]"
                }
                catch {
                    Write-Log -Type Err -Evt "(VM:$Vm) Error getting VM info: $($_.Exception.Message)"
                }

                $VmFixed = $Vm.replace(".","-")
                $VmInfo = Get-VM -Name $Vm

                ## Remove old backups if -LowDisk is configured
                If ($LowDisk)
                {
                    RemoveOld
                }

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
                If (Get-VM | Where-Object {$VmInfo.State -eq 'Running'})
                {
                    $VMwasRunning = $true
                    Write-Log -Type Info -Evt "(VM:$Vm) VM is running, saving state"
                    Stop-VM -Name $Vm -Save
                }

                else {
                    $VMwasRunning = $false
                    Write-Log -Type Info -Evt "(VM:$Vm) VM not running"
                }

                ## If -OptimiseVHD option is set attempt to optimise the VMs VHDs
                If ($OptimiseVHD)
                {
                    OptimVHD
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

                $StartTime = $(get-date)

                try {
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
                    Write-Log -Type Info -Evt "(VM:$Vm) Waiting 60 seconds..."
                    Start-Sleep -S 60
                }

                ## Remove old backups if -LowDisk is NOT configured
                If ($LowDisk -eq $false)
                {
                    RemoveOld
                }

                If ($BackupSucc)
                {
                    OptionsRun
                }

                If ($BackupSucc)
                {
                    Write-Log -Type Succ -Evt "(VM:$Vm) Backup Successful"
                    $Succi = $Succi+1
                }
                else {
                    Write-Log -Type Err -Evt "(VM:$Vm) Backup failed"
                    $Faili = $Faili+1
                }

                $elapsedTime = $(get-date) - $StartTime
                $totalTime = "{0:HH:mm:ss}" -f ([datetime]$elapsedTime.Ticks)
                Write-Log -Type Info -Evt "(VM:$Vm) Processed in $totalTime"

                If ($ProgCheck)
                {
                    Notify
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
                ## Get VM info
                try {
                    $VhdSize = Get-VHD -Path $($Vm | Get-VMHardDiskDrive | Select-Object -ExpandProperty "Path") | Select-Object @{Name = "FileSizeGB"; Expression = {[math]::ceiling($_.FileSize/1GB)}}, @{Name = "MaxSizeGB"; Expression = {[math]::ceiling($_.Size/1GB)}}
                    Write-Log -Type Info -Evt "(VM:$Vm) has [$((Get-VMProcessor $Vm).Count)] CPU cores, [$([math]::ceiling((Get-VMMemory $Vm).Startup / 1gb))GB] RAM, Storage: [Current Size = $($VhdSize.FileSizeGB)GB - Max Size = $($VhdSize.MaxSizeGB)GB]"
                }
                catch {
                    Write-Log -Type Err -Evt "(VM:$Vm) Error getting VM info: $($_.Exception.Message)"
                }

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
                $VmFixed = $Vm.replace(".","-")

                ## Remove old backups if -LowDisk is configured
                If ($LowDisk)
                {
                    RemoveOld
                }

                $StartTime = $(get-date)

                try {
                    Write-Log -Type Info -Evt "(VM:$Vm) Attempting to export VM"
                    $Vm | Export-VM -Path "$WorkDir" -ErrorAction 'Stop'
                    $BackupSucc = $true
                }
                catch {
                    $_.Exception.Message | Write-Log -Type Err -Evt "(VM:$Vm) $_"
                    $BackupSucc = $false
                }

                ## Remove old backups if -LowDisk is NOT configured
                If ($LowDisk -eq $false)
                {
                    RemoveOld
                }

                If ($BackupSucc)
                {
                    OptionsRun
                }

                If ($BackupSucc)
                {
                    Write-Log -Type Succ -Evt "(VM:$Vm) Export Successful"
                    $Succi = $Succi+1
                }
                else {
                    Write-Log -Type Err -Evt "(VM:$Vm) Export failed"
                    $Faili = $Faili+1
                }

                $elapsedTime = $(get-date) - $StartTime
                $totalTime = "{0:HH:mm:ss}" -f ([datetime]$elapsedTime.Ticks)
                Write-Log -Type Info -Evt "(VM:$Vm) Processed in $totalTime"

                If ($ProgCheck)
                {
                    Notify
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
        ## End of standard export block
        ##
    }

    ## If there are no VMs, then do nothing.
    else {
        Write-Log -Type Err -Evt "There are no VMs running to backup"
    }

    Write-Log -Type Info -Evt "Process finished."
    Write-Log -Type Info -Evt "Number of VMs to Backup:$($Vms.count)"
    Write-Log -Type Info -Evt "Backups Successful:$Succi"
    Write-Log -Type Info -Evt "Backups Failed:$Faili"

    If ($Null -ne $LogHistory)
    {
        ## Clean up logs.
        Write-Log -Type Info -Evt "Deleting logs older than: $LogHistory days"
        Get-ChildItem -Path "$LogPath\Hyper-V-Backup_*" -File | Where-Object CreationTime -lt (Get-Date).AddDays(-$LogHistory) | Remove-Item -Recurse
    }

    If ($ProgCheck -eq $false)
    {
        Notify
    }
}
## End