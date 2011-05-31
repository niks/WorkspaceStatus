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

ls -1 | while read projectName
do
	if test -d "$projectName"
	then
		cd "$projectName"
		projectType=""
		localstatus=$localStatusUnknown
		serverstatus=$serverStatusUnknown
		info=""
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
			info="\e["$colorSVN"m[$branch]\e[m"
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
			info="\e["$colorGIT"m[$branch]\e[m"
		else
			projectType=$typeNONE
		fi		
		printf "%7b %-30.30s $localstatus $serverstatus $info" "$projectType" "$projectName$dots"
		echo ""
		cd ..
	fi
done