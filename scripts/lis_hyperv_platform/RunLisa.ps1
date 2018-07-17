
#######################################################################
# 
# Examples:
#	.\RunLisa.ps1 -vmName "FreebsdStable11" -hvServer "localhost" -suiteTest "debug" -DebugCases "BuildKernel" -kernelGitBranch "master" -kernelCommitID "123456789"
#	.\RunLisa.ps1 -vmName "FreebsdStable11" -hvServer "localhost" -suiteTest "debug" -DebugCases "Heartbeat" 
#
#######################################################################

param([string] $vmName, 
	[string] $hvServer, 
	[string] $suiteTest,
	[string] $DebugCases,
	[string] $kernelGitBranch,
	[string] $kernelCommitID )

$gitFolder = "CI"	
Copy-Item .\$gitFolder\scripts\lis_hyperv_platform\UpdateXmlConfig.ps1 .\BIS\WS2012R2\lisa
Copy-Item .\$gitFolder\scripts\lis_hyperv_platform\UtilsOfUpdateXmlConfig.ps1 .\BIS\WS2012R2\lisa

# Copy tools
$gitFolder = "BIN"
$binDir = "$pwd" + "\BIS\WS2012R2\lisa\bin"
$status = Test-Path $binDir 
if( $status -ne "True" )
{
	New-Item  -ItemType "Directory" $binDir
}
Copy-Item $gitFolder\tools\*   $binDir


# Copy ssh-key
$sshDir = "$pwd" + "\BIS\WS2012R2\lisa\ssh"
$status = Test-Path $sshDir 
if( $status -ne "True" )
{
	New-Item  -ItemType "Directory" $sshDir
}
Copy-Item $gitFolder\ssh\*   $sshDir


cd .\BIS\WS2012R2\lisa

# Update the xml file firstly

if( $kernelGitBranch -and  $kernelCommitID )
{
	.\UpdateXmlConfig.ps1   -vmName $vmName  -hvServer $hvServer -suiteTest $suiteTest -DebugCases $DebugCases  -kernelGitBranch $kernelGitBranch -kernelCommitID $kernelCommitID
}
else
{
	.\UpdateXmlConfig.ps1   -vmName $vmName  -hvServer $hvServer -suiteTest $suiteTest -DebugCases $DebugCases
}

#Now, run lisa test

.\lisa.ps1 run run.xml

cd ..\..\..


