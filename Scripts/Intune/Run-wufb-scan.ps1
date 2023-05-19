try
{
C:\Windows\System32\usoclient.exe startinteractivescan
Write-output "Scan success"
}
catch
{
Write-output "Scan NOT success"
}