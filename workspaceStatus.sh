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
	branchName=$1
	remote=$(git config branch.$branchName.remote)
	if test -n "$remote"
	then 
		remoteBranch=$(git config branch.$branchName.merge | sed 's/refs\/heads\///')
		ahead=$(git log --oneline $remote/$remoteBranch..$branchName | wc -l)
		echo $ahead
	else 
		echo -1
	fi
}

function printGitBranchStatus() {
	branchName=$1
	aheadCount=$2
	branchColor=$3
	
	if test $aheadCount -ge 0
	then 
		remote=$(git config branch.$branchName.remote)
		remoteBranch=$(git config branch.$branchName.merge | sed 's/refs\/heads\///')
		if test $aheadCount -gt 0
		then
			printf "\e["$branchColor"m%-20.20s \e[1;31mis ahead of $remote/$remoteBranch by %s commits \e[m\n" "["$branchName"]"$dots $aheadCount
		else 
			printf "\e["$branchColor"m%-20.20s \e[0;32mis pushed completely to $remote/$remoteBranch\e[m\n" "["$branchName"]"$dots
		fi
	else 
		printf "\e["$branchColor"m%-20.20s\e[m does not track a remote branch\n" "["$branchName"]"$dots
	fi
}

function gitstatus() {
	currentBranch=$(git name-rev --name-only HEAD)
	aheadCount=$(gitBranchAheadCount $currentBranch)
	
	printGitBranchStatus $currentBranch $aheadCount $colorGIT
	
	git show-ref --heads | sed 's/^.* refs\/heads\///' | while read branchName
	do
		if test $currentBranch != $branchName
		then
			printf "%-49.49s" ""
			aheadCount=$(gitBranchAheadCount $branchName)
			printGitBranchStatus $branchName $aheadCount ""
		fi
	done
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
				gitsvnstatus=$(git log trunk..HEAD)
				if test -n "$gitsvnstatus"
				then
					serverstatus=$uncommitted
				else
					serverstatus=$committed
				fi
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
		
		if test "$projectType" = "$typeGIT"
		then
			printf "%-30.30s %7b $localstatus " "$projectDir$dots" "$projectType" 
			gitstatus $projectDir
		else 
			printf "%-30.30s %7b $localstatus $currentBranch $serverstatus\n" "$projectDir$dots" "$projectType" 
		fi
		
		cd ..
	fi
done