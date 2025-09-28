# baldwin.sh
[![made-with-bash](https://img.shields.io/badge/Made%20with-Bash-1f425f.svg)](https://www.gnu.org/software/bash/)
[![pre-commit](https://img.shields.io/badge/pre--commit-enabled-brightgreen?logo=pre-commit&logoColor=white)](https://github.com/pre-commit/pre-commit)

A dedicated Dev Container for your Secure Code Reviews!

Create a folder for your project. Put the source code archive into the "/input" folder. **baldwin.sh** takes care of the rest!

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/K3K81JFF22)

## Features

The following tasks are automated, thanks to the [Justfile command runner](https://github.com/casey/just):

- **code handover**: creates a checksum (so you can proof which code you reviewed), unzips the archive, calculates the lines of code (LOC) and displays the structure of the archive.

- **technology review**: reports on technologies used and security sensitive parts of the code, like authentication, authorization, logging, ... using [Microsoft Applicatop Inspector](https://github.com/microsoft/ApplicationInspector).

- **static code analysis**: performs a static analysis using [OpenGrep](https://github.com/opengrep/opengrep) and reports on detected vulnerabilities.

- **static code analysis of Infrastructure as Code (IaC)**: performs a static analysis using [Checkmarx KICS](https://github.com/Checkmarx/kics) and reports on misconfigurations or vulnerabilities in cloud related IaC.

- **software composition analysis (SCA)**: reports on vulnerable dependencies using [OWASP dep-scan](https://github.com/owasp-dep-scan/dep-scan) and [Google OSV-scanner](https://github.com/google/osv-scanner).

- **search for hardcoded secrets**: reports on hardcoded secrets in the code using [TruffleHog](https://github.com/trufflesecurity/trufflehog).

All this is done in a dedicated folder, with a specific structure. **baldwin.sh" ensures that software is updated when needed, and results are consistent. It is easy to share findings with your customer or with colleages.

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/K3K81JFF22)

## Introduction

**baldwin.sh** makes the initial discovery part of a secure code review efficient, consistent, auditable and repeatable. Once the dev container has started, enter the following command and the magic will happen:

```bash
just doit
```
The above will run a number of typical tasks that are done at the initial stages of a secure code review.

Every task can also be run individually, if needed. A list of pre-programmed tasks can be displayed with:

```bash
just list
```

You can create a backup of the complete project folder with:

```bash
just backup
```
This will create a backup archive of everything in the `backup` folder.

If, for audit reasons, you need to archive all output from the tools, do:

```bash
just output
```
This will create a backup archive of only the contents of the `output` folder in the `backup` folder.

Note: rather than using a Dev Container, it is possible (curently Ubuntu only) to install and run it with a script.

## Prerequisites and Quickstart

### Using a Dev Container

The most complete setup is using a [devcontainer](https://containers.dev/) on [any Operating System](https://code.visualstudio.com/Download) that supports [Visual Studio Code](https://code.visualstudio.com/).

1. [Download Visual Studio Code](https://code.visualstudio.com/Download) for your platform and install it.

2. From the VSCode marketplace, install the extension [Visual Studio Code Dev Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers).

Clone **baldwin.sh** locally:

```bash
git clone https://github.com/igbuend/baldwin.sh.git
```
Copy the folder to a dedicated project folder, e.g. `~/projects/myproject`:

```bash
mv -T baldwin.sh ~/projects/myproject
```

Now open this folder in Visual Studio code. After a short while, Visual Studio code will detect that a Dev Container configuration is present and will ask to open it into a container. Click "Open in container".

The first time, this might take a while, next time it will be much faster since the required files are already cached by Docker.

When the installation finishes, move the received code archive to the 'input' folder, open a terminal in VSCode and do the following and watch the magic happening:

```bash
just doit
```
This will run all the tools, and save the outputs in the `output` folder.

In case you want to make sure that all tools were up-to-date:

```bash
just do_fresh
```

All tools can be run individually too, if needed. Do the following to list all options:

```bash
just --list
```

### Using the "baldwin.sh" Script

This is currently only supported on Ubuntu.

Some tools use Docker, make sure it is installed and running on your system. Please refer to the [Docker installation docs](https://docs.docker.com/engine/install/ubuntu/).


Another requirement is the "Justfile command runner". Install it as follows:

```bash
wget -qO - 'https://proget.makedeb.org/debian-feeds/prebuilt-mpr.pub' | gpg --dearmor | sudo tee /usr/share/keyrings/prebuilt-mpr-archive-keyring.gpg 1> /dev/null
echo "deb [arch=all,$(dpkg --print-architecture) signed-by=/usr/share/keyrings/prebuilt-mpr-archive-keyring.gpg] https://proget.makedeb.org prebuilt-mpr $(lsb_release -cs)" | sudo tee /etc/apt/sources.list.d/prebuilt-mpr.list
sudo apt update
sudo apt install just
```

Get this code:

```bash
git clone https://github.com/igbuend/baldwin.sh.git
```

Conclude the installation as follows:

```bash
cd baldwin.sh
./configure
make
sudo make install
```

From then, you can use `baldwin.sh` as follows.

Create a folder for your project:

```bash
baldwin.sh --output ~/projects/myproject
```

Copy the source code archive (to be reviewed) into the `input` folder, e.g. if your customer gave you a `sources.zip` archive do the following:

```bash
cp sources.zip ~projects/myproject/input
```

Now change into the project folder and install all needed tools:

```bash
cd ~projects/myproject/
just upgrade
```

Now run all tools, the results will be in the `output` folder:

```bash
just doit
```

All tools can be run individually too, if needed. Do the following to list all options:

```bash
just --list
```

## Create your Personalised baldwin.sh

If you like to thinker with the `justfile` to use other tools, you might want to create your personalised `baldwin.sh` too.

Edit the `justfile`, make certain it works, and create the modified `baldwin.sh` in the `baldwin folder:

```bash
just baldwin
```

Just copy the `bin/baldwin.sh` to `/usr/local/bin` and it is ready to use.

You can now let your AI go crazy with this circular feature: create a modified `justfile`, use it to create a modified `baldwin.sh`, use the modified `baldwin.sh` to create a new proejct folder with a modified `justfile` that created the `baldwin.sh`. What came first? The chicken or the egg?

## Frequently Asked Questions (FAQ)

### Why the name **baldwin**?

Baldwin is a character in the medieval fable of [**Reynard the Fox**](https://en.wikipedia.org/wiki/Reynard_the_Fox). It is a gruesome story, describing the unspeakable atrocities of the cunning fox. A tale of horrors, not unlike what a reviewer experiences during a secure code review.

Oh yes, Baldwin is the ass (a donkey, you donkey!) in the story.

### What is **malpertus**?

Malpertus is one of the myriad of spellings of the name of the lair of [**Reynard the Fox**](https://en.wikipedia.org/wiki/Reynard_the_Fox). After trying to make sense of supposedly readable and maintainable code that devs produce, one might prefer to stare in the comforting black and bottomless abyss for a while.

## Future (depends on how much coffee I can afford)

- v1.0 More consistent handling of errors/output and better documentation
- v2.0 Automated vulnerability report of all output

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/K3K81JFF22)

## Licensing

The code in this project is licensed under the [MIT license](LICENSE).