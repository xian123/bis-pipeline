#!/bin/csh

#Note: This script is csh, not bash.
#      This script is only for FreeBSD10.0 or higher version.

set logFileOfBuildKernel=/root/kernelbuilding.log
set logFile=/root/autobuild.log       
set srcPath = /usr/devsrc/
set buildworldFlag  =  "no"     #Do not build world by default 
set sourceCodeURL  =  "https://github.com/freebsd/freebsd.git"
set git_branch = "master"
set app
set applications = ("bash unix2dos git")

date > "/tmp/tempLogForAutoBuild.log"

#Provide help information 
if( $#argv >= 1 ) then
	if( "$argv[1]" == "-h" || "$argv[1]" == "--help" ) then
		echo "Usage:"
		echo "       ./autobuild.sh [--buildworld] [--git_url <URL>] [--git_branch <branch>] [--log <filename>]"
		echo " "
		echo "Parameters:"
		echo "           --buildworld: need to build world"
		echo "           --git_url: source code URL"
		echo "           --git_branch: git branch name"
		echo "           --log: log file name"
		echo " "
		echo "Example:"
		echo "         ./autobuild.sh --git_branch master --git_url https://github.com/freebsd/freebsd.git --log /tmp/build.log"
		exit 0
	endif
endif

#Parse input parameters
@ i = 1
while( $i <= $#argv )
    if( "$argv[$i]" == "--git_url" ) then
        @ i = $i + 1
        if( $i >  $#argv ) then
            echo "Error: Please specify a source code URL" | tee -a "/tmp/tempLogForAutoBuild.log"
            exit 1
        else
            set sourceCodeURL  = $argv[$i] 
        endif
    endif
	
	if( "$argv[$i]" == "--log" ) then
        @ i = $i + 1
        if( $i >  $#argv ) then
            echo "Error: Please give a log file name" | tee -a "/tmp/tempLogForAutoBuild.log"
            exit 1
        else
            set logFile  = $argv[$i] 
        endif
    endif
	
	if( "$argv[$i]" == "--git_branch" ) then
        @ i = $i + 1
        if( $i >  $#argv ) then
            echo "Error: Please give a branch name" | tee -a "/tmp/tempLogForAutoBuild.log"
            exit 1
        else
            set git_branch  = $argv[$i] 
        endif
    endif
	
	if( "$argv[$i]" == "--git_commit_id" ) then
        @ i = $i + 1
        if( $i >  $#argv ) then
            echo "Error: Please give a commit ID" | tee -a "/tmp/tempLogForAutoBuild.log"
            exit 1
        else
            set git_commit_id  = $argv[$i] 
        endif
    endif
	
	if( "$argv[$i]" == "--buildworld" ) then
	    set buildworldFlag  = "yes"
	endif
	
    @ i = $i + 1
end

cat /tmp/tempLogForAutoBuild.log > $logFile

#To install bash, vim, unix2dos, git and so on.
#You can add other applications in this script in the future.
pkg update 
foreach  app ($applications) 
pkg info $app 
if ( $? == 0 ) then
    echo " " >> $logFile
else
    echo "Start to install $app ..."
    pkg install $app  <<HERE
y
HERE
    if ( $? == 0 ) then 
        echo "$app install successful!"    >> $logFile
    else
        echo "Error:$app install failed!"  >> $logFile
    endif
endif
end

pkg info bash  
if ( $? == 0 ) then
    if ( -e /bin/bash ) then 
        echo " " >> $logFile 
    else
        ln -sf /usr/local/bin/bash  /bin/bash
        if ( $? == 0 ) then 
            echo "ln -s /usr/local/bin/bash  /bin/bash successful!"    >> $logFile
        else
            echo "Error:ln -s /usr/local/bin/bash  /bin/bash failed!"  >> $logFile
        endif
    endif
endif


#A directory to store the source code from URL
if( ! -e $srcPath ) then
    mkdir -p $srcPath
endif

cd $srcPath

#Get the source code from the URL
echo "------------------------------------------"   >> $logFile
echo "The branch is: $git_branch"   >> $logFile
echo "The source code URL is: $sourceCodeURL"   >> $logFile
echo "------------------------------------------"   >> $logFile

set repoName = `echo  "git clone $sourceCodeURL" | sed 's/.*\///' | sed 's/\.git//'`
set tryTimes = 0 
set TOTALTIMES = 3 

#Try to use the previous code if it exists for loadoff network
if( -e ${srcPath}${repoName} ) then
    cd ${srcPath}${repoName}
    echo "Start to git checkout $git_branch and it maybe take a long time ..."  >> $logFile
    @ tryTimes = 0
    while( $tryTimes < $TOTALTIMES )
        git checkout $git_branch
        if( $? != 0 ) then
            @ tryTimes = $tryTimes + 1
            sleep 10
            echo "Warning: try to git checkout $git_branch again. Try times: $tryTimes of $TOTALTIMES"  >> $logFile
            continue
        endif
        break
    end
    
    if( $tryTimes >= $TOTALTIMES ) then
        echo "Warning: git checkout $git_branch for the first loop unseccessfully."  >> $logFile
        echo "It will try again after git clone the code."  >> $logFile
        cd $srcPath
        rm -rf $repoName
    endif
    
endif

#Update the code if the above steps failed or its the first time to run 
if( !  -e ${srcPath}${repoName} ) then
    echo "Start to git clone code from $sourceCodeURL and it maybe take a long time ..."  >> $logFile
    @ tryTimes = 0
    while( $tryTimes < $TOTALTIMES )
        git clone $sourceCodeURL
        if( $? != 0 ) then
            @ tryTimes = $tryTimes + 1
            sleep 30
            echo "Warning: try to git clone $sourceCodeURL again. Try times: $tryTimes of $TOTALTIMES"  >> $logFile
            continue
        endif
        break
    end
    
    if( $tryTimes >= $TOTALTIMES ) then
        echo "Error: git clone $sourceCodeURL failed."  >> $logFile
        exit 1
    endif
    
    echo "git clone $sourceCodeURL successfully."  >> $logFile
    echo "Start to git checkout $git_branch ..."  >> $logFile
    cd ${srcPath}${repoName}
    
    @ tryTimes = 0
    while( $tryTimes < $TOTALTIMES )
        git checkout $git_branch
        if( $? != 0 ) then
            @ tryTimes = $tryTimes + 1
            sleep 10
            echo "Warning: try to git checkout $git_branch again. Try times: $tryTimes of $TOTALTIMES"  >> $logFile
            continue
        endif
        break
    end
    
    if( $tryTimes >= $TOTALTIMES ) then
        echo "Error: git checkout $git_branch failed."  >> $logFile
        exit 1
    endif
    
endif

echo "git checkout $git_branch successfully."  >> $logFile
echo "Start to git pull origin $git_branch ..."  >> $logFile

#Try TOTALTIMES times to update code based on unstabel network factor 
@ tryTimes = 0
while( $tryTimes < $TOTALTIMES )
	git pull origin $git_branch
	if( $? != 0 ) then
		@ tryTimes = $tryTimes + 1
		echo "Warning: try to git pull origin $git_branch again. Try times: $tryTimes of TOTALTIMES"  >> $logFile
        sleep 10
		continue
	endif
	
	break
end

if( $tryTimes >= $TOTALTIMES ) then
    echo "Error: git pull origin $brt $git_branch failed."  >> $logFile
    exit 1
endif

date >> $logFile
date > $logFileOfBuildKernel
echo "Update the source code successfully."  >> $logFile


git checkout -f $git_commit_id
echo "git checkout commit ID: $git_commit_id ."  >> $logFile


#Build the tool chain firstly, but the process continue even it's failed
echo "Begin to build tool chain and it will take a very long time."  >> $logFileOfBuildKernel
make -j `sysctl -n hw.ncpu` kernel-toolchain  >> $logFileOfBuildKernel
if( $? != 0 ) then
	echo "Warning: Build tool chain failed." >> $logFile
	echo "Warning: Build tool chain failed." >> $logFileOfBuildKernel
endif

#Build world if necessary 
if( $buildworldFlag == "yes" ) then
    date >> $logFile
    echo "Begin to build world and it will take a very long time."  >> $logFile
    echo "Begin to build world and it will take a very long time."  >> $logFileOfBuildKernel
    make -j `sysctl -n hw.ncpu` buildworld  >> $logFileOfBuildKernel
	if( $? != 0 ) then
	    echo "Error: Build world failed." >> $logFile
	    exit 1
    endif 
	echo "Build world successfully."  >> $logFile
	date >> $logFile
endif

#Build kernel  
echo "Begin to build kernel and it will take a long time."  >> $logFile
echo "Begin to build kernel and it will take a long time."  >> $logFileOfBuildKernel
uname -p | grep "i386"
if( $? == 0 ) then
	echo "The processor is i386."     >> $logFile
	make -j `sysctl -n hw.ncpu` buildkernel KERNCONF=GENERIC TARGET=i386 TARGET_ARCH=i386  >> $logFileOfBuildKernel
	if( $? != 0 ) then
	    echo "Error: Build kernel failed." >> $logFile
		exit  1
	endif
else
	echo "The processor is amd64."    >> $logFile 
	make -j `sysctl -n hw.ncpu` buildkernel KERNCONF=GENERIC   >> $logFileOfBuildKernel
	if( $? != 0 ) then
	    echo "Error: Build kernel failed." >> $logFile
		exit  1
	endif
endif

date >> $logFile
echo "Build kernel successfully."  >> $logFile


#Install kernel
echo "Begin to install kernel and it will take a moment."  >> $logFile
echo "Begin to install kernel and it will take a moment."  >> $logFileOfBuildKernel
make installkernel KERNCONF=GENERIC  >> $logFileOfBuildKernel
if( $? != 0 ) then
	echo "Error: Install kernel failed."  >> $logFile
	exit 1
endif   
echo "Install kernel successfully."  >> $logFile

#Install world if necessary
if( $buildworldFlag == "yes" ) then
    echo "Begin to install world and it will take a moment."  >> $logFile
    echo "Begin to install world and it will take a moment."  >> $logFileOfBuildKernel
    make installworld  >> $logFileOfBuildKernel
    if( $? != 0 ) then
        echo "Error: Install world failed."  >> $logFile
        exit 1
    endif   
    echo "Install world successfully."  >> $logFile
endif

echo "To reboot VM after syncing, building and installing kernel/world."  >>  $logFile
date >> $logFile
sync
sync

/sbin/shutdown -r now



