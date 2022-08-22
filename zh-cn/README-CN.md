# Hyper-V 备份工具

多功能 Hyper-V 备份工具

请前往我的网站查看完整的修订日记和更多信息, [我的网站.](https://gal.vin/utils/hyperv-backup-utility/)

Hyper-V 备份工具现已在以下平台发布 :

* [GitHub](https://github.com/Digressive/HyperV-Backup-Utility)
* [The Microsoft PowerShell Gallery](https://www.powershellgallery.com/packages/Hyper-V-Backup)

请考虑捐赠我:

* 注册 [Patreon](https://www.patreon.com/mikegalvin).
* 使用贝宝一次新捐赠 [PayPal](https://www.paypal.me/digressive).

如果你需要联系我，请私聊我的推特 [tweet or DM](https://twitter.com/mikegalvin_), 或者你可以加入我的 [Discord server](https://discord.gg/5ZsnJ5k).

-Mike

我是此 ReadMe 翻译者，如有翻译错误请提 issuse 或 直接邮箱联系我 developer024h@gmail.com

-Developer024


## 功能 和 要求

* 此工具只适用于 Hyper-V 宿主机
* 此工具要求 Hyper-V 宿主机必须安装 Hyper-V management PowerShell 模块
* 此工具可以导出 Hyper-V 无导出权限的虚拟机
* 此工具可以导出 Hyper-V 集群
* 此工具要求 Windows PowerShell 版本至少 5.0 以上
* 此工具在 Windows 11, Windows 10, Windows Server 2022, Windows Server 2019 和 Windows Server 2016 上测试通过

## 支持 7-Zip 压缩工具

我已经把 7-Zip 集成进了此脚本. 现在你可以使用所有 7-Zip 的 shell 功能 。不过经过亲自测试有效的命令是，其它参数还得自测.

* '-t' 测试压缩包完整性
* '-p' 为压缩包设置密码
* '-v' 指定分卷大小
* ...

## 当使用 -NoPerms 参数时

-NoPerms 是为了给某些没有常规导出 Hyper-V 虚拟机权限的路径使用，多见于 NAS 设备. （此参数会关闭虚拟机进行复制）

Hyper-V 的导出操作要求 Active Directory 中的计算机帐户有权访问存储导出的位置. 我建议为 Hyper-V 宿主机创建一个 Active Directory 组，然后为该组授予所需的 “完全控制” 文件和共享权限。

把 威联通 或 群晖 这种 NAS 设备作为存储, Hyper-V 将无法完成操作，因为计算机帐户将无法访问 NAS 上的共享，如果要完整地复制备份所需的所有文件，VM必须处于脱机状态才能完成操作，因此在复制过程中将关闭该VM。

## 当使用 -List 参数时

如果你现在有 VM1，VM2，VM3，VM4 ，你不需要 VM1，VM2 参加备份工作。 你需要新建一个 vms.txt 文件，类似于

```
VM3
VM4
```

特别注意 vms.txt 里是需要参加备份的虚拟机名称。 

## 创建密码文件

用于SMTP服务器身份验证的密码必须在加密文本文件中。如果要生成密码文件，请在计算机上的PowerShell中运行以下命令，并以将运行该实用程序的用户身份登录。当您运行该命令时，系统将提示您输入用户名和密码。输入要用于向SMTP服务器进行身份验证的用户名和密码。

请注意：只有当您通过电子邮件发送日志时需要向SMTP服务器进行身份验证时，才需要此选项。

``` powershell
$creds = Get-Credential
$creds.Password | ConvertFrom-SecureString | Set-Content c:\scripts\ps-script-pwd.txt
```

运行这些命令后，您将拥有一个包含加密密码的文本文件。在配置 -pwd 参数时，输入该文件的路径和文件名。

##  配置

下方是脚本的参数 和 基本用法

| 参数 | 描述 | 示例 |
| -- | -- | -- |
| -BackupTo | 把虚拟机备份到的路径。每个 VM 在此位置中都会自动创建自己的文件夹。 | [path\] |
| -List | 把需要备份的虚拟机名称输入到 vms.txt 中，如果没有此参数将会自动备份所有运行中的虚拟机 | [path\]vms.txt |
| -Wd | 在移至最终磁盘前先备份虚拟机备份文件至缓存盘| [path\] |
| -NoPerms | 关闭正在运行的 VM 以执行基于文件拷贝的备份，而不是使用 Hyper-V 的导出功能。如果未指定列表并且多个 VM 正在运行，则该进程将按字母顺序运行这些 VM 。 | N/A |
| -Keep | 指定备份保留的天数，程序将在 number 天后删除备份文件 | [number] |
| -Compress  | 此参数会压缩所有的虚拟机备份文件到 zip 格式 | N/A |
| -Sz | 配置用 7-Zip 来压缩虚拟机备份文件 . 7-Zip 必须安装到默认位置  ```$env:ProgramFiles``` 如果 Windows 未找到 7-Zip 将会使用自带的 windwos compression 压缩. | N/A |
| -SzOptions | 添加此参数来添加 7-Zip 参数支持，参数必须用 ·,· . | "'-t7z,-v2G,-ppassword'" |
| -ShortDate | 此参数将会让备份的虚拟机配置文件只用 年，月，日 来重新命名。 | N/A |
| -L | 将 Log 输出至何处. | [path\] |
| -LogRotate | 将 Log 输出文件保持 number 天后删除。| [number] |
| -NoBanner | 隐藏 shell 上的 ASCII信息。| N/A |
| -Help | 显示脚本帮助信息，未输入任何参数也将显示。| N/A |
| -Subject | 指定邮件的主题，如果未指定将会使用默认值 | "'[Server: Notification]'" |
| -SendTo | e-mail 发送给谁，如果有多个地址，请用 ·,· 分隔. | [example@contoso.com] |
| -From | 邮件发件人邮箱地址. | [example@contoso.com] |
| -Smtp | SMTP地址. | [smtp server address] |
| -Port | SMTP端口，默认25 | [port number] |
| -User | SMTP账号. | [example@contoso.com] |
| -Pwd | 包含用于SMTP身份验证的加密密码的txt文件。 | [path\]ps-script-pwd.txt |
| -UseSsl     | SMTP 是否使用 SSL. | N/A |
## 示例

``` txt
[path\]Hyper-V-Backup.ps1 -BackupTo [path\]
```

这会将正在运行的所有VM备份到指定的备份位置

