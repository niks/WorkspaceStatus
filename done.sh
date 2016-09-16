#!/bin/bash

before=now

if test "$1" = "after" 
then
	shift
	after="$*"
elif test "$*" = "today" 
then
	after="00:00"
elif test "$*" = "yesterday" 
then
	after="yesterday 00:00"
	before="00:00"
elif test "$*" = "this week"
then 
	after="last monday 00:00"
elif test "$*" = "last week"
then 
	after="two monday ago 00:00"
    before="last friday 24:00"
elif test "$*" = "this month"
then 
	after="one month ago"
else 
	echo "Don't understand $*. Assuming after $*"
	after="$*"
fi

echo log commits done after $after and before $before

find . \( \
   -name src \
-o -name bin \
-o -name build \
-o -name deploy \
-o -name release \
-o -name GeneratedStubs \
-o -name MergedStubs \
-o -name MergingStubs \
-o -name Internal \
-o -name External \
-o -path "*/.git/*" \
\) -prune -o \( -name .git -print \) |
while read dir
do 
	user=`git config user.name`
    if test `git --git-dir="$dir" --no-pager log --oneline --after="$after" --before="$before" --author="$user" --all | wc -l` -gt 0
    then
        echo
        echo
        echo done as $user in ${dir%.git}
        git --git-dir=$dir --no-pager log --pretty=format:"%C(yellow)%h %C(cyan)%cd %C(reset)%C(magenta)%ad %Creset%s" --date=short --after="$after" --before="$before" --author="$user" --all
    fi
done
