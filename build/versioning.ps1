<#
function New-Prueba([string]$initialValue)
 {
    New-Module -AsCustomObject -name Prueba -ArgumentList $initialValue -scriptblock {
        param([string]$initialValue)
        $nombre = $null
        $pepe = "Pepe"

        function Init()
        {
            $nombre = $initialValue
        }

        Init
        Export-ModuleMember -Variable *
    } 
}

$prueba1 = New-Prueba "pepe"
$prueba1.dato = "pepe"

$prueba2 = New-Prueba
$prueba2.dato = "raul"

$prueba1.dato
$prueba2.dato

$ver = New-Version "1.0.0.1"

$ver.OriginalValue()
#>
function New-AssemblyInfo([string]$path)
{
    New-Module -AsCustomObject -name AssemblyInfo -ArgumentList $path -scriptblock {
        param([string]$path)
        $versions= @{
            Version = $null
            FileVersion = $null
            InformationalVersion = $null
        }

        function New-Version([string]$initialValue)
        {
    New-Module -AsCustomObject -name Version -ArgumentList $initialValue -scriptblock {
        param([string]$initialValue)
        $original = @{
            Major = $null
            Minor = $null
            Build = $null
            Revision = $null
        }
        $changed = @{
            Major = $null
            Minor = $null
            Build = $null
            Revision = $null
        }

        function OriginalValue()
        {
            return ConvertToString $original
        }

        function ChangedValue()
        {
            return ConvertToString $changed
        }

        function HasChanged()
        {
            $o = OriginalValue
            $c = ChangedValue
            return $o -ne $c
        }

        function Increment([string] $portion)
        {
            if (!$changed.ContainsKey($portion)) {
                throw "The argument `$portion ($portion) is not valid."
            }
            $report = @{}
            $report.OldValue = ChangedValue
            $changed[$portion] +=1
            $report.NewValue = ChangedValue
            return $report
        }

        function Merge($version)
        {
            $report = @{}
            $report.OldValue = ChangedValue
            foreach($key in $version.changed.Keys)
            {
                $portionSource = $version.changed[$key]
                if(($changed[$key] -ne $portionSource) -and ($portionSource -ne "*")){
                    $changed[$key] = $portionSource
                }
            }
            $report.NewValue = ChangedValue
            return $report
        }

        function Reset()
        {
            $changed.Major = $null
            $changed.Minor = $null
            $changed.Build = $null
            $changed.Revision = $null
        }

        function ConvertToString($source)
        {
            $arr = @()
            $arr += [string]$source.Major
            $arr += [string]$source.Minor
            if(([string]($source.Build) -eq "*") -or ($source.Build -ge 0)){
                $arr += [string]$source.Build
            }
            if(([string]($source.Revision) -eq "*") -or ($source.Revision -ge 0)){
                $arr += [string]$source.Revision
            }
            $str = $($arr -join ".")
            return $str
        }

        #========================================
        # Private functions
        #========================================
        function Init()
        {
            $parsed = [Version]::Parse($initialValue.Replace("*",0))
            $original.Major = FixValue $initialValue 0 $parsed.Major
            $original.Minor = FixValue $initialValue 1 $parsed.Minor
            $original.Build = FixValue $initialValue 2 $parsed.Build
            $original.Revision = FixValue $initialValue 3 $parsed.Revision            

            $changed.Major = $original.Major
            $changed.Minor = $original.Minor
            $changed.Build = $original.Build
            $changed.Revision = $original.Revision
        }

        function FixValue([string]$_version,[int]$index,[int]$parsedValue)
        {
            if ($parsedValue -eq -1) {
                return $parsedValue
            }
            $value = $_version.Split(".")[$index]
            if ($value -eq "*") {
                return $value
            }
            return [int]$value
        }
        
		Init
        Export-ModuleMember -Variable * -function OriginalValue, ChangedValue, HasChanged, Increment, Merge, Reset
    } 
        }


        function GetDefiniteVersion()
        {
            $version = $versions["InformationalVersion"]
            if ($version -eq $null) { 
                $version = $versions["Version"]
            }
            return $version.changedValue()
        }

        function IncrementVersions([string] $portion)
        {
            $output = @()
            $output += $(IncrementVersion $portion)
            $version = $versions["Version"]
            foreach($key in $versions.Keys) {
                if ($key -ne "Version") {
                    $item = $versions[$key]
                    if ($item -ne $null) {
                        $report = $item.Merge($version)
                        $report.VersionType = $key
                        $output += $report
                    }
                }
            }
            return $output
        }

        function IncrementVersion([string] $portion) {
            $key = "Version"
            $version = $versions[$key]
            $report = $version.Increment($portion)
            $report.VersionType = $key
            return $report
        }

        function RevertChanges()
        {
            foreach($key in $versions.Keys) {
                $item = $versions[$key]
                if ($item -ne $null) {
                    $item.Revert()
                }
            }
        }

        function Save()
        {
            $contents = [System.IO.File]::ReadAllText($path)
            $replaced = $false
            foreach($key in $versions.Keys) {
                $item = $versions[$key]
                if ($item -ne $null -and $item.hasChanged()) {
                    $originalValue = $item.OriginalValue()
                    $changedValue = $item.ChangedValue()
                    $search = GetReplacement $key $originalValue
                    $replace = GetReplacement $key $changedValue
                    $contents = $contents.Replace($search,$replace) 
                    $replaced = $true
                }
            }
            if ($replaced) {
                [System.IO.File]::WriteAllText($path, $contents)
            }
        }

        #========================================
        # Private functions
        #========================================
        function Init()
        {
            $contents = [System.IO.File]::ReadAllText($path)
            $versionNumberPattern = "(?<version>[0-9]+(?:\.(?:[0-9]+|\*)){1,3})"
            foreach($key in @($versions.Keys)) {
                $pattern = GetPattern $key $versionNumberPattern
                $match = [Regex]::Match($contents,$pattern)
                if ($match.Success) {
                    $versions[$key] = New-Version $match.Groups["version"].Value
                }
            }
        }

        function GetPattern ([string]$versionType, [string]$value)
        {
            return [string]::Format("Assembly{0}\(`"{1}`"\)",$versionType, $value)
        }

        function GetReplacement ([string]$versionType, [string]$value)
        {
            return [string]::Format("Assembly{0}(`"{1}`")",$versionType, $value)
        }
        
        Init
        Export-ModuleMember -Variable * -function IncrementVersions, RevertChanges, GetDefiniteVersion, Save #-Variable *
    }
}
