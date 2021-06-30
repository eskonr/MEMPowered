<#
.SYNOPSIS
	This script generate the status messages for sms provider, site server and client.
Author: Eswar Koneti
Date:15-Nov-2019
#>

<#param( 
    [Parameter(Mandatory=$True)] 
    [string]$stringPathToDLL, 
    [Parameter(Mandatory=$True)] 
    [string]$stringOutputCSV 
) #>

$scriptpath = $MyInvocation.MyCommand.Path
$dir = Split-Path $scriptpath
$date = (get-date -f dd-MM-yyyy-HHmmss)

$Dllfiles=Get-ChildItem -Path "$dir\*.dll" -Recurse
foreach ($file in $Dllfiles)
{

    $dir=$File.Directory.FullName
    $dll=$file.name
    $strOutputCSV =  $dir+"\"+$dll+".csv"
    $stringPathToDLL = $dir+"\"+$dll
 
#Start Invoke Code 
$sigFormatMessage = @' 
[DllImport("kernel32.dll")] 
public static extern uint FormatMessage(uint flags, IntPtr source, uint messageId, uint langId, StringBuilder buffer, uint size, string[] arguments); 
'@ 
 
$sigGetModuleHandle = @' 
[DllImport("kernel32.dll")] 
public static extern IntPtr GetModuleHandle(string lpModuleName);
'@ 
 
$sigLoadLibrary = @' 
[DllImport("kernel32.dll")] 
public static extern IntPtr LoadLibrary(string lpFileName); 
'@ 
 
$Win32FormatMessage = Add-Type -MemberDefinition $sigFormatMessage -name "Win32FormatMessage" -namespace Win32Functions -PassThru -Using System.Text 
$Win32GetModuleHandle = Add-Type -MemberDefinition $sigGetModuleHandle -name "Win32GetModuleHandle" -namespace Win32Functions -PassThru -Using System.Text 
$Win32LoadLibrary = Add-Type -MemberDefinition $sigLoadLibrary -name "Win32LoadLibrary" -namespace Win32Functions -PassThru -Using System.Text 
#End Invoke Code 
 
$sizeOfBuffer = [int]16384 
$stringArrayInput = {"%1","%2","%3","%4","%5", "%6", "%7", "%8", "%9"} 
$flags = 0x00000800 -bor 0x00000200  
$stringOutput = New-Object System.Text.StringBuilder $sizeOfBuffer 
$colMessages = @() 

#Load Status Message Lookup DLL into memory and get pointer to memory 
$ptrFoo = $Win32LoadLibrary::LoadLibrary($stringPathToDLL.ToString()) 
$ptrModule = $Win32GetModuleHandle::GetModuleHandle($stringPathToDLL.ToString()) 
 
#Find Informational Status Messages 
for ($iMessageID = 1; $iMessageID -ile 99999; $iMessageID++) 
{ 
    $result = $Win32FormatMessage::FormatMessage($flags, $ptrModule, 1073741824 -bor $iMessageID, 0, $stringOutput, $sizeOfBuffer, $stringArrayInput) 
     
    if( $result -gt 0) 
    { 
        $objMessage = New-Object System.Object 
        $objMessage | Add-Member -type NoteProperty -name MessageID -value $iMessageID 
        $objMessage | Add-Member -type NoteProperty -name MessageString -value $stringOutput.ToString().Replace("%11","").Replace("%12","").Replace("%3%4%5%6%7%8%9%10","") 
        $objMessage | Add-Member -type NoteProperty -name Severity -value "Informational" 
        $colMessages += $objMessage 
        #$iMessageID 
        #$stringOutput.ToString() 
    } 
     
    #$previousString = $stringOutput.ToString() 
} 
 
#Find Warning Status Messages 
for ($iMessageID = 1; $iMessageID -ile 99999; $iMessageID++) 
{ 
    $result = $Win32FormatMessage::FormatMessage($flags, $ptrModule, 2147483648 -bor $iMessageID, 0, $stringOutput, $sizeOfBuffer, $stringArrayInput) 
     
    if( $result -gt 0) 
    { 
        $objMessage = New-Object System.Object 
        $objMessage | Add-Member -type NoteProperty -name MessageID -value $iMessageID 
        $objMessage | Add-Member -type NoteProperty -name MessageString -value $stringOutput.ToString().Replace("%11","").Replace("%12","").Replace("%3%4%5%6%7%8%9%10","") 
        $objMessage | Add-Member -type NoteProperty -name Severity -value "Warning" 
        $colMessages += $objMessage 
        #$iMessageID 
        #$stringOutput.ToString() 
    } 
 
    #$previousString = $stringOutput.ToString() 
} 
 
#Find Error Status Messages 
for ($iMessageID = 1; $iMessageID -ile 99999; $iMessageID++) 
{ 
    $result = $Win32FormatMessage::FormatMessage($flags, $ptrModule, 3221225472 -bor $iMessageID, 0, $stringOutput, $sizeOfBuffer, $stringArrayInput) 
     
    if( $result -gt 0) 
    { 
        $objMessage = New-Object System.Object 
        $objMessage | Add-Member -type NoteProperty -name MessageID -value $iMessageID 
        $objMessage | Add-Member -type NoteProperty -name MessageString -value $stringOutput.ToString().Replace("%11","").Replace("%12","").Replace("%3%4%5%6%7%8%9%10","") 
        $objMessage | Add-Member -type NoteProperty -name Severity -value "Error" 
        $colMessages += $objMessage 
        #$iMessageID 
        #$stringOutput.ToString() 
    } 
     
    #$previousString = $stringOutput.ToString()
} 
 
$colMessages | Export-CSV -path $strOutputCSV -NoTypeInformation
}

$csvs = Get-ChildItem "$dir\*.csv"
$y=$csvs.Count
Write-Host "Detected the following CSV files: ($y)"
foreach ($csv in $csvs)
{
Write-Host " "$csv.Name
}
$outputfilename = "StatusMessages-$date.xlsx" #creates file name with date/username
Write-Host Creating: $outputfilename
$excelapp = new-object -comobject Excel.Application
$excelapp.sheetsInNewWorkbook = $csvs.Count
$xlsx = $excelapp.Workbooks.Add()
$sheet=1

foreach ($csv in $csvs)
{
$row=1
$column=1
$worksheet = $xlsx.Worksheets.Item($sheet)
$worksheet.Name = $csv.Name
$file = (Get-Content $csv)
foreach($line in $file)
{
$linecontents=$line -split ',(?!\s*\w+")'
foreach($cell in $linecontents)
{
$worksheet.Cells.Item($row,$column) = $cell
$column++
}
$column=1
$row++
}
$sheet++
}
$output = $dir + "\" + $outputfilename
$xlsx.SaveAs($output)
$excelapp.quit()
cd \ #returns to drive root
Remove-Item "$dir\*.csv" -Recurse -Force -ErrorAction SilentlyContinue