#!/bin/bash

clean="\e[0;32m[clean]\e[m"
dirty="\e[1;31m[dirty]\e[m"
localStatusUnknown="       "

  committed="\e[0;32m[ committed ]\e[m"
uncommitted="\e[1;31m[uncommitted]\e[m"
serverStatusUnknown="             "


colorNONE="0;33"
colorSVN="1;35"
colorGIT="1;36"
colorGIT_SVN="1;36"

   typeNONE="\e["$colorNONE"m  [none] \e[m"
    typeSVN="\e["$colorSVN"m  [svn]  \e[m"
    typeGIT="\e["$colorGIT"m  [git]  \e[m"
typeGIT_SVN="\e["$colorGIT_SVN"m[git-svn]\e[m"

dots="................................................"
if test -z "$*" 
then
	DIRS='*'
else
	DIRS="$*"
fi

function gitBranchAheadCount() {
	localBranch=$1
	remote=$2
	remoteBranch=$3
	if test -n "$remote"
	then 
		ahead=$(git log --oneline $remote/$remoteBranch..$localBranch | wc -l)
		echo $ahead
	else 
		echo -1
	fi
}

function printGitBranchStatus() {
	localBranch=$1
	branchColor=$2
	remote=$3
	remoteBranch=$4
	aheadCount=$5
	
	if test -n "$remote"
	then 
		if test $aheadCount -gt 0
		then
			printf "\e["$branchColor"m%-20.20s \e[1;31mis ahead of $remote/$remoteBranch by %s commits \e[m\n" "["$localBranch"]"$dots $aheadCount
		else 
			printf "\e["$branchColor"m%-20.20s \e[0;32mis pushed completely to $remote/$remoteBranch\e[m\n" "["$localBranch"]"$dots
		fi
	else 
		printf "\e["$branchColor"m%-20.20s\e[m does not track a remote branch\n" "["$localBranch"]"$dots
	fi
}

function gitstatus() {
	currentBranch=$(git name-rev --name-only HEAD)
	remote=$(git config branch.$currentBranch.remote)
	remoteBranch=$(git config branch.$currentBranch.merge | sed 's/refs\/heads\///')

	aheadCount=$(gitBranchAheadCount $currentBranch $remote $remoteBranch)
	
	printGitBranchStatus "$currentBranch" "$colorGIT" "$remote" "$remoteBranch" "$aheadCount"
	
	git show-ref --heads | sed 's/^.* refs\/heads\///' | while read branchName
	do
		if test $currentBranch != $branchName
		then
			remote=$(git config branch.$branchName.remote)
			remoteBranch=$(git config branch.$branchName.merge | sed 's/refs\/heads\///')			
			aheadCount=$(gitBranchAheadCount $branchName $remote $remoteBranch)
			
			printf "%-49.49s" ""
			printGitBranchStatus "$branchName" "" "$remote" "$remoteBranch" "$aheadCount"
		fi
	done
}

function gitSvnStatus() {
	currentBranch=$(git name-rev --name-only HEAD)
	
	remoteWithBranch=$(git name-rev --refs "refs/remotes/*" HEAD | sed 's/^.* //')
	remote=${remoteWithBranch%/*}
	remoteBranch=${remoteWithBranch#remotes/}

	aheadCount=$(gitBranchAheadCount $currentBranch $remote $remoteBranch)
	
	printGitBranchStatus "$currentBranch" "$colorGIT" "$remote" "$remoteBranch" "$aheadCount"
	
	git show-ref --heads | sed 's/^.* refs\/heads\///' | while read branchName
	do
		if test $currentBranch != $branchName
		then
			remoteWithBranch=$(git name-rev --refs "refs/remotes/*" $currentBranch | sed 's/^.* //')
			if test "$remoteWithBranch" != "undefined"
			then
				remote=${remoteWithBranch%/*}
				remoteBranch=${remoteWithBranch#remotes/}
				aheadCount=$(gitBranchAheadCount $branchName $remote $remoteBranch)
				
				printf "%-49.49s" ""
				printGitBranchStatus "$branchName" "" "$remote" "$remoteBranch" "$aheadCount"
			else 
				printf "%-49.49s" ""
				printf "%-20.20s \e[1;31m%s\e[m\n" "["$localBranch"]"$dots "[unknown status: cannot determine remote name!]"
			fi
		fi
	done
}

function svnStatus() {
	printf "$currentBranch $serverstatus\n"

}

ls -1 -d $DIRS | while read projectDir
do
	if test -d "$projectDir"
	then
		cd "$projectDir"
		projectType=""
		localstatus=$localStatusUnknown
		serverstatus=$serverStatusUnknown
		currentBranch=""
		if test -d ".svn"
		then
			projectType=$typeSVN
			svnstatus=$(svn status --ignore-externals)
			if test -n "$svnstatus"
			then
				localstatus=$dirty
			else 
				localstatus=$clean
			fi
			branch=$(svn info | grep '^URL:' | sed -r "s/.*((tags|branches)\/(.*)|(trunk))/\1/")
			currentBranch="\e["$colorSVN"m[$branch]\e[m"
		elif test -d ".git"
		then
			if test -d ".git/svn"
			then
				projectType=$typeGIT_SVN
			else
				projectType=$typeGIT
			fi
			gitstatus=$(git status --porcelain)
			if test -n "$gitstatus"
			then
				localstatus=$dirty
			else 
				localstatus=$clean
			fi
			branch=$(git name-rev --name-only HEAD)
			currentBranch="\e["$colorGIT"m[$branch]\e[m"
		else
			projectType=$typeNONE
		fi
		
		printf "%-30.30s %7b $localstatus " "$projectDir$dots" "$projectType" 
		
		if test "$projectType" = "$typeGIT"
		then
			gitstatus $projectDir
		elif test "$projectType" = "$typeGIT_SVN"
		then
			gitSvnStatus $projectDir
		else 
			printf "$currentBranch $serverstatus\n"
		fi
		
		cd ..
	fi
done