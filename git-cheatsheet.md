**Git Cheat Sheet**

*Set up local branch:*
```shell script
git checkout -b  <branch name>
```

*Publish local branch:*
```shell script
git push -u origin <branch name>
```

*Checkout and track remote branch:*
```shell script
git checkout -t origin/<branch name>
```

*Merge branch into master:*
```shell script
git checkout master
git merge <branch name>
git push
```

*Remove remote branch:*
```shell script
git push origin :<branch name>
```

*Sync local branches with remote:*
```shell script
git remote prune origin
```

*Rename just commited commit:*
```shell script
git commit --amend -m "your new message"
```

*Move uncommited changes to another branch:*
```shell script
git stash
git checkout correct-branch
git stash pop
```

*Remove all branches by mask:*
```shell script
git branch | grep -E 'release-0.10-.*' | xargs git branch -d
```

*Add and share tag:*
```shell script
git tag -a <tag name> -m "<commit message>"
git push origin <tag name>
```

*GitHub pull requests as local branch*
https://gist.github.com/piscisaureus/3342247
```shell script
git fetch origin pull/<pr-number>/head:pull-<pr-number>
git checkout pull/<pr-number>
```
