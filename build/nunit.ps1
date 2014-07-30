# 
# Copyright (c) 2011-2012, Toji Project Contributors
# 
# Dual-licensed under the Apache License, Version 2.0, and the Microsoft Public License (Ms-PL).
# See the file LICENSE.txt for details.
#


properties {
  Write-Progress "Loading nunit properties"
  $nunit = @{}
  $nunit.runner = (Get-ChildItem "$($tools.dir)\*" -recurse -include nunit-console-x86.exe).FullName
  Write-Success
}

function Invoke-TestRunner {
  param(
    [Parameter(Position=0,Mandatory=$true)]
    [string[]]$dlls = @(),
	[Parameter(Position=1,Mandatory=$true)]
    [string]$tests_bin_dir,
	[Parameter(Position=2,Mandatory=$true)]
    [string]$test_results_dir
  )

  Assert ((Test-Path($nunit.runner)) -and (![string]::IsNullOrEmpty($nunit.runner))) "NUnit runner could not be found"
  
  if ($dlls.Length -le 0) { 
     Write-Output "No tests defined"
     return 
  }
  exec { & $nunit.runner $dlls /work:$($tests_bin_dir) /out:$($test_results_dir)\TestResults.txt /result:$($test_results_dir)\TestResults.xml /noshadow /nologo }
}