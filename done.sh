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
	after="one week ago"
elif test "$*" = "last week"
then 
	after="two weeks ago"
elif test "$*" = "this month"
then 
	after="one month ago"
else 
	echo "Don't understand $*. Assuming today"
	after="00:00"
fi

echo log commits done after $after and before $before

find . -maxdepth 3 -name ".git" -prune | 
while read dir
do 
	user=`git config user.name`
	echo done as $user in ${dir%.git}
	git --git-dir=$dir log --oneline --after="$after" --before="$before" --author="$user" --all
done
