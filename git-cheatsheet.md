**Git Cheat Sheet**

*Set up local branch:*
`git checkout -b  <branch name>`

*Publish local branch:*
`git push -u origin <branch name>`

*Checkout and track remote branch:*
`git checkout -t origin/<branch name>`

*Merge branch into master:*
`git checkout master`
`git merge <branch name>`
`git push`

*Remove remote branch:*
`git push origin :<branch name>`

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

*GitHub pull requests as local branch*
https://gist.github.com/piscisaureus/3342247
