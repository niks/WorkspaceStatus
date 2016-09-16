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

colorCurrentBranch="1;36"
colorUnknownGitSvnRemote="0;33"

colorUptodate="0;32"
colorIncommingChange="0;36"
colorOutgoingChange="0;31"
colorUntrackedChange="1;31"

   typeNONE="\e["$colorNONE"m  [none] \e[m"
    typeSVN="\e["$colorSVN"m  [svn]  \e[m"
    typeGIT="\e["$colorGIT"m  [git]  \e[m"
typeGIT_SVN="\e["$colorGIT_SVN"m[git-svn]\e[m"

padding='________________________________________'
if test -z "$*" 
then
	DIRS='*'
else
	DIRS="$*"
fi

function printGitBranchStatus() {
	localBranch=$1
	branchColor=$2
	
	remote=$(git config branch.$localBranch.remote)

	maxNameLength=30
	nameDisplayLength=$[${#localBranch}>$maxNameLength?$maxNameLength:${#localBranch}]
	padlength=$[$maxNameLength - $nameDisplayLength]
	branchDisplay=${localBranch: -$nameDisplayLength}
	
	if test -n "$remote"
	then 
		remoteBranchRef=$(git config branch.$localBranch.merge)
		remoteBranch=$remote/$(echo $remoteBranchRef | sed 's/refs\/heads\///')
		remoteTrackingRef=refs/remotes/$remoteBranch

		if git show-ref --verify -q $remoteTrackingRef
		then
			aheadCount=$(git log --oneline $remoteBranch..$localBranch | wc -l | tr -d ' ')
			behindCount=$(git log --oneline $localBranch..$remoteBranch | wc -l | tr -d ' ')

			
			out="    "
			in="    "
			color=""
			if test $aheadCount -eq 0 -a $behindCount -eq 0
			then
				color=$colorUptodate
			else 
				if test $behindCount -gt 0	
				then
					in=$(printf "%3s↓" $behindCount)
					color=$colorIncommingChange
					# FIXME change to orange
				fi
				
				if test  $aheadCount -gt 0	
				then
					out=$(printf "%3s↑" $aheadCount)
					color=$colorOutgoingChange # override with red at this point, even if behind set a color already
				fi
			fi
			printf "\e["$branchColor"m%.*s%0.*s\e["$color"m %s %s %s\e[m\n" $maxNameLength $branchDisplay $padlength "$padding" "$in" "$out" "$remoteBranch"
		else
			printf "\e["$branchColor"m%.*s%0.*s\e[0;31m is configured to track a non-existing branch $remoteBranch\e[m\n" $maxNameLength $branchDisplay $padlength "$padding"
		fi
	else
		printf "\e["$branchColor"m%.*s%0.*s\e["$colorUntrackedChange"m does not track a remote branch" $maxNameLength $branchDisplay $padlength "$padding"
		first=y
		for remote in $(git remote)
		do 
			remoteTrackingRef=refs/remotes/$remote/$localBranch
			if git show-ref --verify -q $remoteTrackingRef
			then
				if test "$first" = "y"
				then 
					printf " \e[0;31mbut a tracking branch exists for: "
				else 
					printf ", "
				fi
				printf "$remote"
			fi
		done
		printf "\e[m\n"
	fi
}

function gitstatus() {
	currentBranch=$(git name-rev --name-only HEAD)
	
	printGitBranchStatus "$currentBranch" "$colorCurrentBranch"
	
	git show-ref --heads |  sed 's/^.* //' | while read branch
	do
		branchName=${branch#refs/heads/}
		if test $currentBranch != $branchName
		then
			printf "%-49.49s" ""
			printGitBranchStatus "$branchName" ""
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
	
	git show-ref --heads |  sed 's/^.* //' | while read branch
	do
		branchName=${branch#refs/heads/}
		if test $currentBranch != $branchName
		then
			remoteWithBranch=$(git name-rev --refs "refs/remotes/*" $branch | sed 's/^.* //')
			if test "$remoteWithBranch" != "undefined"
			then
				remote=${remoteWithBranch%/*}
				remoteBranch=${remoteWithBranch#remotes/}
				aheadCount=$(gitBranchAheadCount $branch $remote $remoteBranch)
				
				printf "%-49.49s" ""
				printGitBranchStatus "$branchName" "" "$remote" "$remoteBranch" "$aheadCount"
			else 
				printf "%-49.49s" ""
				printf "%-20.20s \e[$colorUnknownGitSvnRemote""m%s\e[m\n" "["$branchName"]$padding" "[unknown status: cannot determine remote branch]"
			fi
		fi
	done
}

function svnStatus() {
	branch=$(svn info | grep '^URL:' | sed -r "s/.*((tags|branches)\/(.*)|(trunk))/\1/")
	printf "\e["$colorCurrentBranch"m[$branch]\e[m\n"

}

baseDir=$(pwd)
ls -1 -d $DIRS | while read projectDir
do
	if test -d "$projectDir"
	then
		cd "$projectDir"
		projectType=""
		workspaceStatus=$localStatusUnknown
		if test -d ".svn"
		then
			projectType=$typeSVN
			svnstatus=$(svn status --ignore-externals)
			if test -n "$svnstatus"
			then
				workspaceStatus=$dirty
			else 
				workspaceStatus=$clean
			fi
		elif test -e ".git"
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
				workspaceStatus=$dirty
			else 
				workspaceStatus=$clean
			fi
		else
			projectType=$typeNONE
		fi
		
		printf "%-30.30s %7b $workspaceStatus " "$projectDir$padding" "$projectType" 
		
		if test "$projectType" = "$typeGIT"
		then
			gitstatus $projectDir
		elif test "$projectType" = "$typeGIT_SVN"
		then
			gitSvnStatus $projectDir
		elif test "projectType" = "$typeSVN"
		then
			svnStatus $projectDir
		else
			printf "\n"
		fi
		
		cd $baseDir
	fi
done