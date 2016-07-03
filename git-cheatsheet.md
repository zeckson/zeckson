**Git Cheat Sheet**

*Set up local branch:*
`git checkout  -b  <branch name>`

*Publish local branch:*
`git push  -u origin <branch name>`

*Checkout and track remote branch:*
`git checkout -t origin/<branch name>`

*Remove remote branch:*
`git push origin  :<branch name>`

*Sync local branches with remote:*
`git remote prune origin`

*Rename just commited commit:*
`git commit --amend -m "your new message"`

*Move uncommited changes to another branch:*
`git stash`
`git checkout correct-branch`
`git stash pop`

*Remove all branches by mask:*
`git branch | grep -E 'release-0.10-.*' | xargs git branch -d`

*Add and share tag:*
`git tag -a <tag name> -m "<commit message>"`
`git push origin <tag name>`