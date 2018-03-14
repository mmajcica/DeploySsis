[CmdletBinding()]
param()

Trace-VstsEnteringInvocation $MyInvocation

try
{
    $ispacFilePath = Get-VstsInput -Name "ispacFilePath"
    $InstanceName = Get-VstsInput -Name "serverName" -Require
    $authScheme = Get-VstsInput -Name "authscheme" -Require
    $sqlUsername = Get-VstsInput -Name "sqlUsername"
    $sqlPassword = Get-VstsInput -Name "sqlPassword"
    $catalogPassword = Get-VstsInput -Name "catalogPassword"
    $sharedCatalog = Get-VstsInput -Name "sharedCatalog" -AsBool
    $folderName = Get-VstsInput -Name "folderName" -Require
    $environmentsFilePath = Get-VstsInput -Name "environmentsFilePath"
    $defaultWorkingDir = Get-VstsTaskVariable -Name "system.defaultworkingdirectory"

    $CatalogName = "SSISDB" # Catalog name is a constant

    [Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo") | Out-Null
    [Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Management.IntegrationServices") | Out-Null
    Import-Module -Name $PSScriptRoot\ps_modules\ispac.psm1

    Write-Verbose "Finding files with pattern $ispacFilePath"
    $found = Find-VstsFiles -LegacyPattern "$ispacFilePath"

    if (-not $found)
    {
        throw "No files found using search pattern '$ispacFilePath'."
    }

    $ispacs = @()

    # Find-Files returns an array in case of multiple objects, a single item in case single item is found.
    if ($found -is [System.Array])
    {
        foreach ($filePath in $found)
        {
            $file = (Get-Item $filePath)

            if ($file.Extension -eq ".ispac")
            {
                $ispacs += $file
            }
        }
    }
    else
    {
        $file = (Get-Item $found)

        if ($file.Extension -eq ".ispac")
        {
            $ispacs += $file
        }
    }

    if (-not $ispacs)
    {
        throw "No ISPAC'S found using search pattern '$ispacFilePath'."
    }

    Write-Output "Matched files:"
    $ispacs | ForEach-Object { $_.FullName } | Write-Output

    Write-Output "Checking CLR on the SQL Server ...."
    Test-SqlClrEnabled $InstanceName
    Write-Output "CLR is enabled on $InstanceName."

    if ($authScheme -eq "windowsAuthentication")
    {
        $connectionString = Get-SqlConnectionString $InstanceName
    }
    else
    {
        $connectionString = Get-SqlConnectionString $InstanceName -IntegratedSecurity $false -Username $sqlUsername -Password $sqlPassword
    }

    Write-Verbose "Connection string $connectionString"

    New-SsisCatalog $connectionString $CatalogName $catalogPassword $sharedCatalog
    New-SsisFolder $connectionString $CatalogName $folderName

    $ispacs | Add-SsisProject $connectionString $CatalogName $folderName

    if ($environmentsFilePath -ne $defaultWorkingDir) #meaning that, if the value is supplied, go for it
    {
        $configurationFile = [System.IO.FileInfo]$environmentsFilePath

        if ($configurationFile.Exists -and $configurationFile.Extension -in (".xml", ".json"))
        {
            $settings = Get-Config -FilePath $environmentsFilePath

            foreach($environment in $settings.environments)
            {
                New-SsisEnvironment $connectionString $CatalogName $folderName $environment.name $environment.description $environment.ReferenceOnProjects
                Set-SsisEnvironmentVariables $connectionString $CatalogName $folderName $environment.name $environment.variables $environment.ReferenceOnProjects
            }
        }
        else
        {
            throw "Specified configuration file '$environmentsFilePath' is not valid."
        }
    }
}
finally
{
    Trace-VstsLeavingInvocation $MyInvocation
}
