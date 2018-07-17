
<#
Fuc: Update the xml configuration.

Execute the script examples:
	.\UpdateXmlConfig.ps1 -vmName "FreebsdStable11" -hvServer "localhost" -suiteTest "debug" -DebugCases "BuildKernel" -kernelGitBranch "master" -kernelCommitID "123456789"
	.\UpdateXmlConfig.ps1 -vmName "FreebsdStable11" -hvServer "localhost" -suiteTest "debug" -DebugCases "Heartbeat" 
#>



param([string] $vmName, 
	[string] $hvServer, 
	[string] $suiteTest,
	[string] $DebugCases,
	[string] $kernelGitBranch,
	[string] $kernelCommitID )

Function UpdateXmlConfig([string]$originalConfigFile, [string]$newConfigFileDirctory, [string]$newConfigFileName)
{
	<#
	Usage:
		UpdateXmlConfig $originalConfigFile $newConfigFileDirctory $newConfigFileName
	Description:
		This is a function to update xml configuration.
	#>
	
	$newConfigFile = "$newConfigFileDirctory\$newConfigFileName"
    
    # The $newConfigFileName is a copy of $originalConfigFile. All changes will be written into the $newConfigFileName
    Copy-Item $originalConfigFile $newConfigFile
    
    #For FreeBSD 10.3, the VM bus protocol version is not supported
    if( $vmName -eq "FreeBSD10.3")
    {
        $content = get-content $newConfigFile
        clear-content $newConfigFile
        foreach ($line in $content)
        {
            $liner = $line.Replace("<suiteTest>VmbusProtocolVersion</suiteTest>","")
            Add-content $newConfigFile -Value $liner
        }
        sleep 1
    }

	[xml]$xml = Get-Content "$newConfigFile"
	
	# Update parameter of OnGuestReadHostKvpData test case
	$target = $xml.config.testCases.test  | Where {$_.testName -eq "OnGuestReadHostKvpData"}
	$i = 0
	foreach( $param in $target.testparams.param)
	{
		$i++
		if($param | Select-String -pattern "Value=.*")
		{
			$myFQDN=(Get-WmiObject win32_computersystem).DNSHostName+"."+(Get-WmiObject win32_computersystem).Domain
			Write-Host "FQDN of host: $myFQDN"
			$target.testparams.ChildNodes[$i-1].InnerText="Value=$myFQDN"
			break
		}
	}

	# Update parameter of BuildKernel test case
	if( $kernelGitBranch )
	{
		$target = $xml.config.testCases.test  | Where {$_.testName -eq "BuildKernel"}
		$i = 0
		foreach( $param in $target.testparams.param)
		{
			$i++
			if($param | Select-String -pattern "GIT_BRANCH=.*")
			{
				$target.testparams.ChildNodes[$i-1].InnerText="GIT_BRANCH=$kernelGitBranch"
				break
			}
		}	
	}

	if( $kernelCommitID -and $kernelCommitID -ne "None" )
	{
		$target = $xml.config.testCases.test  | Where {$_.testName -eq "BuildKernel"}
		$i = 0
		foreach( $param in $target.testparams.param)
		{
			$i++
			if($param | Select-String -pattern "GIT_COMMITID=.*")
			{
				$target.testparams.ChildNodes[$i-1].InnerText="GIT_COMMITID=$kernelCommitID"
				break
			}
		}	
	}
	
	# Update vmName
	$xml.config.VMs.vm.vmName = $vmName
	
	# Update test suite
	$xml.config.VMs.vm.suite = $suiteTest
	
	# Update test hvServer
	$server = $hvServer
	$xml.config.VMs.vm.hvServer = $server
	
	if($DebugCases -and $DebugCases.Trim() -ne "")
	{
		$debugCycle = $xml.SelectSingleNode("/config/testSuites/suite[suiteName=`"debug`"]")
		if($debugCycle)
		{
			foreach($testcase in $debugCycle.suiteTests)
			{
				$testcase = $debugCycle.RemoveChild($testcase)
			}
		}
		else
		{
			$debugCycle = $xml.CreateElement("suite")
			$name = $xml.CreateElement("suiteName")
			$name.InnerText = "DEBUG"
			$name = $debugCycle.AppendChild($name)
			$debugCycle = $xml.DocumentElement.testSuites.AppendChild($debugCycle)
		}
		
		$debugCase = $xml.CreateElement("suiteTests")
		foreach($cn in ($DebugCases).Trim().Split(","))
		{
			$debugCaseName = $xml.CreateElement("suiteTest")
			$debugCaseName.InnerText = $cn.Trim()
			$debugCaseName = $debugCase.AppendChild($debugCaseName)
			$debugCase = $debugCycle.AppendChild($debugCase)
		}
	}

	$xml.Save("$newConfigFile")
    
    return 0
}

"`n`n"
"#############################################################"
"`n"
"VM name: $vmName"
"Test suite: $suiteTest"
"Test cases: $DebugCases"
"Git branch: $kernelGitBranch"
"Git commit: $kernelCommitID"
"`n"
"#############################################################"
"`n`n"


. .\UtilsOfUpdateXmlConfig.ps1  | out-null


"Begin to prepare the xml for test"

$testReport = "report.xml"
$status = Test-Path $testReport  
if( $status -eq "True" )
{
	"Delete the old $testReport"
	Remove-Item   $testReport  -Force
}

"The vm name is:  $vmName"
#To stop the vm before test
$sts = DoStopVM $VMName $hvServer
if($sts[-1] -ne 0)
{
	"Error: Stop the vm failed."
	return 1
}

# Update the memory on the VM
$memory = 2048 * 1MB	#Memory is 2GB
$mem = Set-VM -Name $vmName -ComputerName $hvServer -MemoryStartupBytes $memory
if ($? -eq "True")
{
    "Update memory successfully."
}
else
{
    "Warn: Unable to update memory."
}

#Delete all IDE and SCSI disks except the OS disk
DeleteDisks $vmName $hvServer

# Create the base snapshot if it doesn't exist
$existBaseSnapshot = $False
$baseSnapshotName = "Base"
$snaps = Get-VMSnapshot -VMName $vmName -ComputerName $hvServer 
foreach($s in $snaps)
{
	if ($s.Name -eq $baseSnapshotName)
	{
		$existBaseSnapshot = $True
		break
	}
}

if ( $existBaseSnapshot -eq $False )
{
	$sts = CreateSnapshot $vmName $hvServer  $baseSnapshotName
	if($sts[-1] -ne 0)
	{
		"Warning: Create $baseSnapshotName snapshort failed."
	}
}


# Update config for CI Run
$XmlConfigFile = "FreeBSD_WS2012R2.xml"
$osversion = [environment]::OSVersion.Version.Build
if( $osversion -eq "9200" )   #9200 means the host os is Windows Server 2012
{
    "The test is runnig on Windows Server 2012."
    $XmlConfigFile = "FreeBSD_WS2012.xml"
}

if( Test-Path "$pwd\xml\freebsd\$XmlConfigFile" )
{
	$sts = UpdateXmlConfig "$pwd\xml\freebsd\$XmlConfigFile" "$pwd" run.xml 
    if( $sts[-1] -ne 0 )
    {
        "Failed to prepare the run.xml and abort the test."
        return 1
    }
}


"Prepare the xml for test done"




