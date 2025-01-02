# Path to the input text file containing SQL Server instance names
$inputTxtFile = "C:\Ido\Source_files\Servers_Instances.txt"  # Replace with your file path

# Path to the output CSV file
$outputCsvFile = "C:\Ido\Results\SysAdminsList$(Get-Date -Format "yyyyMMdd").csv"

# Initialize an empty array to store the results
$sysAdminResults = @()

# Read server names from the text file
$serverNames = Get-Content -Path $inputTxtFile

# Check if the file contains any server names
if ($serverNames.Count -eq 0) {
    Write-Host "No servers found in the input text file."
    exit
}

# Define the T-SQL query to fetch sysadmin logins with the provided filter
$query = @"
SELECT name, type_desc, is_disabled
FROM master.sys.server_principals 
WHERE IS_SRVROLEMEMBER ('sysadmin', name) = 1
AND name NOT IN ('SOLAREDGE\DB-Admin', 'SESU', 'NT SERVICE\Winmgmt')
--AND name NOT LIKE '%NT SERVICE%'
--AND name NOT LIKE '%NT AUTHORITY%'
AND name NOT LIKE '%Domain Admins%'
AND name NOT LIKE '%svc_cvdb%'
AND name NOT LIKE '%SQLWriter%'
AND name NOT LIKE 'SVC_%DB'
AND is_disabled <> 1
ORDER BY name, type_desc
"@

# Loop through each server in the list
foreach ($serverName in $serverNames) {
    Write-Host "Processing $serverName..."

    try {
        # Execute T-SQL query using Invoke-DbaQuery (DBAtools cmdlet)
        $logins = Invoke-DbaQuery -SqlInstance $serverName -Query $query

        # If logins are returned, process them
        if ($logins) {
            # Add server name to the results
            foreach ($sysAdmin in $logins) {
                $sysAdminResults += [PSCustomObject]@{
                    ServerName  = $serverName
                    LoginName   = $sysAdmin.name
                    LoginType   = $sysAdmin.type_desc
                    IsDisabled  = $sysAdmin.is_disabled
                }
            }
        } else {
            Write-Host "No sysadmin logins found on server $serverName."
        }
    } catch {
        Write-Host "Error processing server $serverName : $_"
    }
}

# If we have results, export to CSV
if ($sysAdminResults.Count -gt 0) {
    $sysAdminResults | Export-Csv -Path $outputCsvFile -NoTypeInformation
    Write-Host "SysAdmin login details have been saved to $outputCsvFile"
} else {
    Write-Host "No sysadmin logins found across all servers."
}