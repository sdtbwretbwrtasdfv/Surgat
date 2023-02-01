#!/bin/bash
# v0.1

find . -name .DS_Store -print0 | xargs -0 git rm -f --ignore-unmatch


git pull 
git add .
echo "Provide comment for commit:"
	read comment
git commit -m $comment
git push 
git push origin
