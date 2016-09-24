#Screenshot of Hyper-V Guests and emails attachment
## usage: .\screenshotv1.ps1 -hvhost localhost -hvguest vmname -imagepath c:\temp\vmshapshots
## get-vm | where {$_.name -match 'sandbox'} | where {$_.state -eq 'off'} | foreach-object {start-vm $_.name;start-sleep -s 30; .\screenshotv1.ps1 -hvhost localhost -imagepath c:\temp -hvguest $_.name; stop-vm -force $_.name}
## Original: https://blogs.msdn.microsoft.com/taylorb/2008/07/29/hyper-v-wmi-creating-a-thumbnail-image/ 

#### Variable Section ####
Param(
[Parameter(ValueFromPipelineByPropertyName)]
[string]$HVHOST,
[string]$HVGUEST,
[string]$ImagePath
)
[System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")
$xRes = 640
$yRes = 480
$FileName = "$ImagePath\$HVGUEST\VM-$HVGUEST-$(Get-date -format yyyy-MM-dd-hh-mm-ss).jpg"
$EmailTo = "" 
$EmailSubject = "Boot Screen for VM - $HVGUEST on $env:computername" 
$EmailFrom = "" 
$EmailSmtpServer = ""
$EmailBody = "Attached is a screenshot of $HVGuest booting."


#### Variable Section ####

#### Create folder for screens ####
IF (!(test-path $ImagePath\$HVGUEST\)) {
	mkdir $ImagePath\$HVGUEST\
}
#### Create folder for screens ####

#### Grab screenshot of VM from WMI interface ####
$VMManagementService = Get-WmiObject -class "Msvm_VirtualSystemManagementService" -namespace "root\virtualization\v2" -ComputerName $HVHOST
$Vm = Get-WmiObject -Namespace "root\virtualization\v2" -ComputerName $HVHOST -Query "Select * From Msvm_ComputerSystem Where ElementName='$HVGUEST'"
$VMSettingData = Get-WmiObject -Namespace "root\virtualization\v2" -Query "Associators of {$Vm} Where ResultClass=Msvm_VirtualSystemSettingData AssocClass=Msvm_SettingsDefineState" -ComputerName $HVHOST
$RawImageData = $VMManagementService.GetVirtualSystemThumbnailImage($VMSettingData, "$xRes", "$yRes") #| ProcessWMIJob $VMManagementService.PSBase.ClassPath "GetVirtualSystemThumbnailImage"

#### Grab screenshot of VM from WMI interface ####

#### Create Bitmap image ####
$VMThumbnail = new-object System.Drawing.Bitmap($xRes, $yRes, [System.Drawing.Imaging.PixelFormat]::Format16bppRgb565)

$rectangle = new-object System.Drawing.Rectangle(0,0,$xRes,$yRes)
[System.Drawing.Imaging.BitmapData] $VMThumbnailBitmapData = $VMThumbnail.LockBits($rectangle, [System.Drawing.Imaging.ImageLockMode]::WriteOnly, [System.Drawing.Imaging.PixelFormat]::Format16bppRgb565)
[System.Runtime.InteropServices.marshal]::Copy($RawImageData.ImageData, 0, $VMThumbnailBitmapData.Scan0, $xRes*$yRes*2)
$VMThumbnail.UnlockBits($VMThumbnailBitmapData);

$VMThumbnail
$VMThumbnail.Save($FileName) 
#$VMThumbnail.Save("$ImagePath\VM[$HVGUEST].jpg") 

#### Create Bitmap image ####

start-sleep -s 2

#### Email image files ####

Send-MailMessage -To $EmailTo -subject $EmailSubject -From $EmailFrom -SmtpServer $EmailSmtpServer -Attachments $FileName -Body $EmailBody -BodyAsHtml

#### Email image files ####

#del $ImagePath\$HVGUEST\VM[$HVGUEST]-$(Get-date -format yyyy-MM-dd-hh-mm-ss).jpg
start-sleep -s 2