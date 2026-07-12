# Contributing to openmediavault-themekit

First off, thank you for considering contributing to openmediavault-themekit! It's people like you that make openmediavault-themekit such a great tool.

## Where do I go from here?

If you've noticed a bug or have a feature request, make one! It's generally best if you get confirmation of your bug or approval for your feature request this way before starting to code.

## Fork & create a branch

If this is something you think you can fix, then fork openmediavault-themekit and create a branch with a descriptive name.

A good branch name would be (where issue #325 is the ticket you're working on):

```sh
git checkout -b 325-add-new-theme
```

## Get the test suite running

Make sure your changes are working by testing the plugin locally on an OpenMediaVault instance.

## Implement your fix or feature

At this point, you're ready to make your changes! Feel free to ask for help; everyone is a beginner at first :smile_cat:

## Make a Pull Request

At this point, you should switch back to your master branch and make sure it's up to date with openmediavault-themekit's master branch:

```sh
git remote add upstream git@github.com:snakkarike/openmediavault-themekit.git
git checkout master
git pull upstream master
```

Then update your feature branch from your local copy of master, and push it!

```sh
git checkout 325-add-new-theme
git rebase master
git push --set-upstream origin 325-add-new-theme
```

Finally, go to GitHub and make a Pull Request :D
