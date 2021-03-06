#  PARAMETERS
param(
	[Parameter( Position = 0, Mandatory = 0, HelpMessage = "Relative Path to Source" )]
	[string] $source_path, 
	[Parameter( Position = 1, Mandatory = 0, HelpMessage = "Relative Path to Tools" )]
	[string] $tools_path = ".\..\tools",
	[Parameter( Position = 2, Mandatory = 0, HelpMessage = "Relative Path to nupkg folder" )]
	[string] $nupkg_path,
	[Parameter( Position = 3, Mandatory = 0, HelpMessage = "Should the script pack dlls or source code" )]
	[bool] $pack_source_code_only = $false,
	[Parameter( Position = 4, Mandatory = 0, HelpMessage = "Print debug info" )]
	[bool] $show_debug = $false
)
#  /PARAMETERS


#  CONFIG
if ($show_debug) {
	$DebugPreference = "Continue"
}
#  /CONFIG



#  DEPENDENCIES
Include _key.ps1
Include utils.ps1
Include nunit.ps1
Include nuget.ps1
Include versioning.ps1
#  /DEPENDENCIES



properties {
	Write-Header "Loading Properties"
    Write-Progress "Loading solution properties"
    $conf = @{}
    $conf.source_dir = Set-Source-Path($source_path)
    $conf.configuration = "Release"
    $conf.version = "1.0.0.0"

    #SOLUTION
    $conf.solution_file = $(Get-ChildItem "$($conf.source_dir)\*.sln" | Select-Object -First 1).FullName
    $conf.solution_name = [System.IO.Path]::GetFileNameWithoutExtension($conf.solution_file)
    $conf.solution_shared_assembly = "$($conf.source_dir)\SharedAssemblyInfo.cs"

    #PROJECT
    $conf.project_pattern = "$($conf.source_dir)\*\*.csproj"

	Write-Success
    Write-HashTable-Debug $conf "Configuration variables"
  
    Write-Progress "Loading tools properties"
    $tools = @{}
    $tools.dir = $tools_path
    $tools.transform = "$($tools.dir)\TransformXml.proj"
    Assert (Test-Path($tools.transform)) "Could not find TransformXml.proj"

    $tools.nuget = "$($tools.dir)\nuget\nuget.exe"
    Assert (Test-Path($tools.nuget)) "Could not find nuget exe"

	Write-Success
    Write-HashTable-Debug $tools "Tools variables"

    $locals = @{}
    $locals.projects = @()
    $locals.packages = @()
}




#  TASK NAME FORMAT TASK
FormatTaskName {
   param($taskName)
   Write-Header "Executing Task: $taskName"
}
#  /TASK NAME FORMAT TASK



#  GENERAL TASKS
Task Default -depends Publish
Task Build -depends Rebuild, Test
Task Package -depends Build, Pack
Task Publish -depends Package, Push
Task PublishFiles -depends Update-Version-From-Nuspec, Pack, Push
#  /GENERAL TASKS


#  VERSION RELATED TASKS
Task SetVariables {
    Get-ChildItem $($conf.project_pattern) | ForEach-Object {
        $current = [System.IO.FileInfo]$_
        $proj = @{}
        $proj.Name = $([System.IO.Path]::GetFileNameWithoutExtension($current.Name))
        $proj.Release = "$($current.DirectoryName)\bin\$($conf.configuration)"
        $proj.Dll = "$($proj.Release)\$($proj.Name).dll"
        $proj.AssemblyFile = New-AssemblyInfo "$($current.DirectoryName)\Properties\AssemblyInfo.cs"
        $proj.Nuspec = "$($current.DirectoryName)\$($proj.Name).nuspec"
        $proj.ContainsNuspec = Test-Path $proj.Nuspec
        $locals.projects += (New-Object -TypeName PSObject -Property $proj)
    }
}

TaskTearDown {
    if($Error -and $changed) {
    
    }
}
#  VERSION RELATED TASKS
Task Update-Version-In-AssemblyInfo -depends SetVariables {
    foreach ($project in $locals.projects) {
        $results = $project.AssemblyFile.IncrementVersions("build")
        $project.AssemblyFile.Save()
        if ($results.Length -gt 0) {
            Write-Host "      Updating version for $($project.Name)"
            foreach($result in $results) {
                Write-Host "      $($result.VersionType) from $($result.OldValue) to" -NoNewline
                Write-Success "$($result.NewValue)"
            }
        }     
    }
}

Task Update-Version-From-Nuspec -depends SetVariables {
    $nuspec_file = Get-ChildItem "$(Resolve-Path $conf.source_dir)\" -Recurse -include *.nuspec | Select-Object -First 1
    $conf.version = Get-Nuspec-Version $nuspec_file.FullName $conf.version
    $conf.version = Get-Incremented-Version-Numbers $conf.version "build"
    Update-Nuspec-Version $nuspec_file.FullName $conf.version
}
#  /VERSION RELATED TASKS



#  CLEAN-BUILD-TEST RELATED TASKS
Task Clean -depends SetVariables{
    foreach ($project in $locals.projects) {
        Clean-Directory $project.Release
    }
}

Task Rebuild -depends Update-Version-In-AssemblyInfo {
    Write-Progress "Building $($conf.solution_file)`n`n"
    Exec { msbuild $($conf.solution_file) /t:Rebuild /p:Configuration=$($conf.configuration) /v:minimal /nologo } 
}

Task Test -depends SetVariables {
    $tests_projects = Get-ChildItem "$(Resolve-Path $conf.source_dir)\" -recurse -include *.Tests.csproj | ForEach-Object {
        $current = [System.IO.FileInfo]$_
        $test = @{}
        $test.Name = $([System.IO.Path]::GetFileNameWithoutExtension($current.Name))
        $test.BinDir = "$($current.DirectoryName)\bin\$($conf.configuration)"
        $test.Dll = "$($test.BinDir)\$($test.Name).dll"
        New-Object -TypeName PSObject -Property $test
    }
	if ($tests_projects.Length -eq 0) {
		Write-Host "    " -NoNewline
		Write-Warning "No test projects found."
    } else {
    	$test_results_dir = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath("$($conf.source_dir)\..\TestResults")
		if (!(Test-Path $test_results_dir)) {
			New-Item $test_results_dir -type directory | Out-Null
		}
        foreach($test in $tests_projects) {
            Write-Progress "Running Tests in "
            Write-Success "$($test.Name)`n`n"
            Invoke-TestRunner $($test.Dll) $($test.BinDir) $test_results_dir
        }
    }
}
#  /CLEAN-BUILD-TEST RELATED TASKS



#  NUGET RELATED TASKS
Task Pack -depends SetVariables {
    foreach ($project in $locals.projects) {
        if($project.ContainsNuspec) {
            #borrar paquetes anteriores
            $locals.packages += Create-Nupkg $project.Nuspec $project.Release $conf.configuration $pack_source_code_only $project.AssemblyFile.GetDefiniteVersion()
        }
    }
}

Task Push -depends Pack {
    foreach ($nupkgs in $locals.packages) {
        Push-Nupkg $nupkgs
    }
    <#
    #$nupkgs = @(Get-ChildItem -path "$(Resolve-Path $conf.source_dir)\*\bin" -recurse -attribute Directory "Release" | foreach { Get-ChildItem $_ -File -Recurse -include "*.nupkg" })
    $nupkgs = @(Get-ChildItem "$(Resolve-Path $conf.nuget_nupkg_dir)\" -recurse -include *.nupkg)
    Write-HashTable-Debug $nupkgs "Found nupkg files"
    
    foreach($nupkg in $nupkgs) { 
        Push-Nupkg $nupkg.FullName
    }
    #>
}
#  /NUGET RELATED TASKS
