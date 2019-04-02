function Get-SqlConnectionString()
{
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingPlainTextForPassword", "Password")]
    [CmdletBinding()]
    param
    (
        [string][parameter(Mandatory = $true)]$InstanceName,
        [bool]$IntegratedSecurity = $true,
        [string]$InitialCatalog = "master",
        [string]$Username,
        [string]$Password
    )
    BEGIN
    {
        Write-Verbose "Entering script $($MyInvocation.MyCommand.Name)"
        Write-Verbose "Parameter Values"
        $PSBoundParameters.Keys | ForEach-Object { Write-Verbose "$_ = '$($PSBoundParameters[$_])'" }
    }
    PROCESS
    {
        $builder = New-Object System.Data.SqlClient.SqlConnectionStringBuilder

        $builder['Data Source'] = $InstanceName
        $builder['Initial Catalog'] = $InitialCatalog 

        if ($IntegratedSecurity)
        {
            $builder['Integrated Security'] = $true
        }
        else
        {
            $builder["User ID"] = $Username
            $builder["Password"] = $Password
        }

        return $builder.ConnectionString
    }
    END { }
}

function Test-SqlClrEnabled()
{
    [CmdletBinding()]
    param
    (
        [string][parameter(Mandatory = $true)]$InstanceName
    )
    BEGIN
    {
        Write-Verbose "Entering script $($MyInvocation.MyCommand.Name)"
        Write-Verbose "Parameter Values"
        $PSBoundParameters.Keys | ForEach-Object { Write-Verbose "$_ = '$($PSBoundParameters[$_])'" }
    }
    PROCESS
    {
        $SQLServer = New-Object "Microsoft.SQLServer.Management.SMO.Server" $InstanceName

        if ($SQLServer.Configuration.IsSqlClrEnabled.ConfigValue -eq 0)
        {
            Write-Verbose "CLR is not enabled."
            Write-Verbose "Enabling CLR on the server $InstanceName"
            
            $SQLServer.Configuration.IsSqlClrEnabled.ConfigValue = 1
            $SQLServer.Configuration.Alter() | Out-String | Write-Verbose

            Write-Verbose "CLR enabled on the server $InstanceName successfully"
        }
    }
    END { }
}

function Get-Config()
{
    [CmdletBinding()]
    param
    (
        [System.IO.FileInfo][parameter(Mandatory = $true)]$FilePath
    )
    BEGIN
    {
        Write-Verbose "Entering script $($MyInvocation.MyCommand.Name)"
        Write-Verbose "Parameter Values"
        $PSBoundParameters.Keys | ForEach-Object { Write-Verbose "$_ = '$($PSBoundParameters[$_])'" }
    }
    PROCESS
    {
        $settings = @{ environments = @()}

        if ($FilePath.Extension -eq ".xml")
        {
            [xml]$file = Get-Content $FilePath
            
            if ($file.environments.environment)
            {
                Write-Verbose "Found $($file.environments.environment.Count) environment definitions in the environments files $FilePath"
    
                foreach($environment in $file.environments.environment)
                {
                    $settings.environments += @{ Name = $environment.name; Description = $environment.description; ReferenceOnProjects = [Array]$environment.referenceOnProjects.project.name; Variables =  $environment.variables.variable }
                }
            }

            return $settings
        }
        elseif ($FilePath.Extension -eq ".json")
        {
            $environments = Get-Content -Path $FilePath | ConvertFrom-Json

            if ($environments)
            {
                Write-Verbose "Found $($environments.Count) environment definitions in the environments files $FilePath"
        
                foreach($environment in $environments)
                {
                    $settings.environments += @{ Name = $environment.name; Description = $environment.description; ReferenceOnProjects = $environment.referenceOnProjects; Variables =  $environment.variables }
                }
            }
        }
        else
        {
            throw "Invalid configuration file type."
        }

        return $settings
    }
    END { }
}

function Get-SqlConnectionString()
{
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingPlainTextForPassword", "Password")]
    [CmdletBinding()]
    param
    (
        [string][parameter(Mandatory = $true)]$InstanceName,
        [bool]$IntegratedSecurity = $true,
        [string]$InitialCatalog = "master",
        [string]$Username,
        [string]$Password
    )
    BEGIN
    {
        Write-Verbose "Entering script $($MyInvocation.MyCommand.Name)"
        Write-Verbose "Parameter Values"
        $PSBoundParameters.Keys | ForEach-Object { Write-Verbose "$_ = '$($PSBoundParameters[$_])'" }
    }
    PROCESS
    {
        $builder = New-Object System.Data.SqlClient.SqlConnectionStringBuilder

        $builder['Data Source'] = $InstanceName
        $builder['Initial Catalog'] = $InitialCatalog 

        if ($IntegratedSecurity)
        {
            $builder['Integrated Security'] = $true
        }
        else
        {
            $builder["User ID"] = $Username
            $builder["Password"] = $Password
        }

        return $builder.ConnectionString
    }
    END { }
}

function New-SsisCatalog()
{
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingPlainTextForPassword", "CatalogPassword")]
    [CmdletBinding()]
    param
    (
        [string][parameter(Mandatory = $true)]$ConnectionString,
        [string][parameter(Mandatory = $true)]$CatalogName,
        [string][parameter()]$CatalogPassword,
        [bool]$SharedCatalog = $true
    )
    BEGIN
    {
        Write-Verbose "Entering script $($MyInvocation.MyCommand.Name)"
        Write-Verbose "Parameter Values"
        $PSBoundParameters.Keys | ForEach-Object { Write-Verbose "$_ = '$($PSBoundParameters[$_])'" }
    }
    PROCESS
    {
        $connection = New-Object "System.Data.SqlClient.SqlConnection" $ConnectionString
        $is = New-Object "Microsoft.SqlServer.Management.IntegrationServices.IntegrationServices" $connection

        # Drop the existing catalog if it exists and it's not shared
        if ($is.Catalogs.Count -gt 0 -and (-not $SharedCatalog))
        {
            Write-Verbose "Dropping existing SSIS Catalog $CatalogName on the server $InstanceName"
            $is.Catalogs[$CatalogName].Drop()
        }
        
        # If catalog is set to shared but no catalog is present, set the pwd so it can be created
        if ($is.Catalogs.Count -eq 0 -and $SharedCatalog)
        {
            Write-Warning "No catalog is present and Share Catalog option is set. A new catalog will be created with the default password 'P@ssw0rd'"
            $CatalogPassword = "P@ssw0rd"
        }

        # If catalog is shared and it is already present, skip the creation, otherwise create the catalog
        if ($SharedCatalog -and $is.Catalogs.Count -gt 0)
        {
            Write-Output "This catalog is shared and will not be recreated."
        }
        else
        {
            try
            {
                Write-Output "Creating SSIS Catalog on the server $InstanceName"

                $catalog = New-Object "Microsoft.SqlServer.Management.IntegrationServices.Catalog" ($is, $CatalogName, $CatalogPassword)
                $catalog.Create()
                
                Write-Output "SSIS Catalog has been created successfully on the server $InstanceName"
            }
            catch
            {
                $e = $_.Exception
                $msg = $e.Message

                while ($e.InnerException)
                {
                    $e = $e.InnerException
                    $msg += "`n" + $e.Message
                }

                throw $msg
            }
            finally
            {
                if ($connection)
                {
                    $connection.Dispose()
                }
            }
        }
    }
    END { }
}

function New-SsisFolder()
{
    [CmdletBinding()]
    param
    (
        [string][parameter(Mandatory = $true)]$ConnectionString,
        [string][parameter(Mandatory = $true)]$CatalogName,
        [string][parameter(Mandatory = $true)]$FolderName
    )
    BEGIN
    {
        Write-Verbose "Entering script $($MyInvocation.MyCommand.Name)"
        Write-Verbose "Parameter Values"
        $PSBoundParameters.Keys | ForEach-Object { Write-Verbose "$_ = '$($PSBoundParameters[$_])'" }
    }
    PROCESS
    {
        try
        {
            $connection = New-Object System.Data.SqlClient.SqlConnection $ConnectionString
            $is = New-Object "Microsoft.SqlServer.Management.IntegrationServices.IntegrationServices" $connection

            $catalog = $is.Catalogs[$CatalogName]
            $folder = $catalog.Folders[$FolderName]

            if ($folder)
            {
                Write-Output "SSIS folder $FolderName already exists."
            }
            else
            {
                Write-Output "Creating the $FolderName folder in the SSIS Catalog $CatalogName..."
                
                $catalogFolder = New-Object "Microsoft.SqlServer.Management.IntegrationServices.CatalogFolder" ($catalog, $FolderName, $FolderName)
                $catalogFolder.Create()
                
                Write-Output "The folder $FolderName has been successfully created in the SSIS Catalog $CatalogName."
            }
        }
        catch
        {
            $e = $_.Exception
            $msg = $e.Message

            while ($e.InnerException)
            {
                $e = $e.InnerException
                $msg += "`n" + $e.Message
            }

            throw $msg
        }
        finally
        {
            if ($connection)
            {
                $connection.Dispose()
            }
        }
    }
    END { }
}

function Add-SsisProject()
{
    [CmdletBinding()]
    param
    (
        [string][parameter(Mandatory = $true)]$ConnectionString,
        [string][parameter(Mandatory = $true)]$CatalogName,
        [string][parameter(Mandatory = $true)]$FolderName,
        [bool]$DropProject,
        [System.IO.FileInfo][parameter(Mandatory = $true, ValueFromPipeline = $true)]$ProjectFile
    )
    BEGIN
    {
        Write-Verbose "Entering script $($MyInvocation.MyCommand.Name)"
        Write-Verbose "Parameter Values"
        $PSBoundParameters.Keys | ForEach-Object { Write-Verbose "$_ = '$($PSBoundParameters[$_])'" }
    }
    PROCESS
    {
        try
        {
            Write-Verbose "Processing $ProjectFile..."

            $connection = New-Object System.Data.SqlClient.SqlConnection $ConnectionString
            $is = New-Object "Microsoft.SqlServer.Management.IntegrationServices.IntegrationServices" $connection

            $catalog = $is.Catalogs[$CatalogName]
            $folder  = $catalog.Folders[$FolderName]

            $projectName = $ProjectFile.BaseName

            if($DropProject -and $folder.Projects[$projectName])
            {
                Write-Output "Dropping existing project $projectName"
                $folder.Projects[$projectName].Drop()
            }

            Write-Output "Deploying $projectName project..."

            [byte[]]$ispac = [System.IO.File]::ReadAllBytes($ProjectFile.FullName)
            $folder.DeployProject($projectName, $ispac) | Out-String | Write-Verbose

            Write-Output "Project $projectName has been deployed successfully."
        }
        catch
        {
            $e = $_.Exception
            $msg = $e.Message

            while ($e.InnerException)
            {
                $e = $e.InnerException
                $msg += "`n" + $e.Message
            }

            throw $msg
        }
        finally
        {
            if ($connection)
            {
                $connection.Dispose()
            }
        }
    }
    END { }
}

function New-SsisEnvironment()
{
    [CmdletBinding()]
    param
    (
        [string][parameter(Mandatory = $true)]$ConnectionString,
        [string][parameter(Mandatory = $true)]$CatalogName,
        [string][parameter(Mandatory = $true)]$FolderName,
        [string][parameter(Mandatory = $true)]$EnvironmentName,
        [string]$EnvironmentDescription = "",
        [string[]]$ProjectsReference
    )
    BEGIN
    {
        Write-Verbose "Entering script $($MyInvocation.MyCommand.Name)"
        Write-Verbose "Parameter Values"
        $PSBoundParameters.Keys | ForEach-Object { Write-Verbose "$_ = '$($PSBoundParameters[$_])'" }
    }
    PROCESS
    {
        try
        {
            $connection = New-Object System.Data.SqlClient.SqlConnection $ConnectionString
            $is = New-Object "Microsoft.SqlServer.Management.IntegrationServices.IntegrationServices" $connection

            $catalog = $is.Catalogs[$CatalogName]
            $folder  = $catalog.Folders[$FolderName]

            if ($folder.Environments[$EnvironmentName])
            { 
                Write-Verbose "Dropping existing environment [$EnvironmentName]"
                $folder.Environments[$EnvironmentName].Drop() 
            }

            Write-Output "Creating environment $EnvironmentName."
            $projectEnvironment = New-Object "Microsoft.SqlServer.Management.IntegrationServices.EnvironmentInfo" ($folder, $EnvironmentName, $EnvironmentDescription)
            $projectEnvironment.Create()

            foreach ($projectReference in $ProjectsReference)
            {
                Write-Output "Referencing $EnvironmentName environment to $projectReference project."

                $project = $folder.Projects[$projectReference]

                if ($project)
                {
                    if ($project.References.Name -contains $EnvironmentName)
                    {
                        Write-Verbose "Project reference for the environment $EnvironmentName already exists."
                    }
                    else                        
                    {
                        Write-Verbose "Adding environment reference for $EnvironmentName to project $($project.Name)"
                        $project.References.Add($EnvironmentName, $FolderName)
                        $project.Alter() | Out-String | Write-Verbose
                    }
                }
                else
                {
                    Write-Warning "Unable to reference the environment '$EnvironmentName' to '$projectReference'. Project not found!"
                }
            }
        }
        catch
        {
            $e = $_.Exception
            $msg = $e.Message

            while ($e.InnerException)
            {
                $e = $e.InnerException
                $msg += "`n" + $e.Message
            }

            throw $msg
        }
        finally
        {
            if ($connection)
            {
                $connection.Dispose()
            }
        }
    }
    END { }
}

function Set-SsisEnvironmentVariables()
{
    [CmdletBinding()]
    param
    (
        [string][parameter(Mandatory = $true)]$ConnectionString,
        [string][parameter(Mandatory = $true)]$CatalogName,
        [string][parameter(Mandatory = $true)]$FolderName,
        [string][parameter(Mandatory = $true)]$EnvironmentName,
        [Object[]][parameter(Mandatory = $true)]$EnvironmentVariables,
        [string[]]$ProjectsReference
    )
    BEGIN
    {
        Write-Verbose "Entering script $($MyInvocation.MyCommand.Name)"
        Write-Verbose "Parameter Values"
        $PSBoundParameters.Keys | ForEach-Object { Write-Verbose "$_ = '$($PSBoundParameters[$_])'" }
    }
    PROCESS
    {
        try
        {
            Write-Output "Adding environement variables to $EnvironmentName."

            $connection = New-Object System.Data.SqlClient.SqlConnection $ConnectionString
            $is = New-Object "Microsoft.SqlServer.Management.IntegrationServices.IntegrationServices" $connection

            $catalog = $is.Catalogs[$CatalogName]
            $folder  = $catalog.Folders[$FolderName]
            $projectEnvironment = $folder.Environments[$EnvironmentName]

            # add variables to the environment
            foreach ($envvar in $EnvironmentVariables)
            {
                Write-Verbose "Adding environment variable $($envvar.name) to $EnvironmentName"
                # Adding variable to our environment
                # Constructor args: variable name, type, default value, sensitivity, description
                $projectEnvironment.Variables.Add($envvar.name, $envvar.type, $envvar.value, [bool]::Parse($envvar.sensitive), $envvar.description)
            }

            $projectEnvironment.Alter() | Out-String | Write-Verbose

            $variables = $EnvironmentVariables | Select-Object -ExpandProperty name

            foreach ($projectReference in $ProjectsReference)
            {
                Write-Output "Referencing variables for '$projectReference' project."

                $project = $folder.Projects[$projectReference]

                if ($project)
                {
                    # check if the parameter named as variable exsist
                    # if so, reference it to the project

                    $changed = $false
                    $projectParams = $project.Parameters.GetList() | Select-Object -ExpandProperty Name
                    
                    $matches = $projectParams | Where-Object { $variables -contains $_ }

                    foreach ($match in $matches)
                    {
                            Write-Verbose "Including project parameter reference $match to $($project.Name)"

                            $project.Parameters[$match].Set([Microsoft.SqlServer.Management.IntegrationServices.ParameterInfo+ParameterValueType]::Referenced, $match) 
                            $changed = $true
                    }

                    foreach ($package in $project.Packages)
                    {
                        $packageChanged = $false
                        $packageParams = $package.Parameters.GetList() | Select-Object -ExpandProperty Name
                        
                        $matches = $packageParams | Where-Object { $variables -contains $_ }

                        foreach ($match in $matches)
                        {            
                                Write-Verbose "Including package parameter reference $match to $($package.Name)"
                                $package.Parameters[$match].Set([Microsoft.SqlServer.Management.IntegrationServices.ParameterInfo+ParameterValueType]::Referenced, $match) 
                                $packageChanged = $true
                        }

                        if ($packageChanged)
                        {
                            $package.Alter() | Out-String | Write-Verbose
                        }
                    }

                    if ($changed)
                    {
                        $project.Alter() | Out-String | Write-Verbose
                    }
                }
                else
                {
                    Write-Warning "Unable to reference variables for environment '$EnvironmentName' on '$projectReference'. Project not found!"
                }
            }
        }
        catch
        {
            $e = $_.Exception
            $msg = $e.Message

            while ($e.InnerException)
            {
                $e = $e.InnerException
                $msg += "`n" + $e.Message
            }

            throw $msg
        }
        finally
        {
            if ($connection)
            {
                $connection.Dispose()
            }
        }
    }
    END { }
}