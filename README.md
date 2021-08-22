# tlpsrc2spec

*WARNING*: This is for RPM packager's use. 

Creates RPM Spec file (except for %prep, %build and %install sections) from ~~tlpsrc~~ tlpdb files.

Currently, this program is only for [Momonga Linux](http://www.momonga-linux.org/). If you want to use this framework for your distribution, it is already ready to do this. Please open an issue to request this.

## Installation

1. Install [Crystal](https://crystal-lang.org/) compiler and development package of [RPM](https://rpm.org/)
   - See also the instructions for [crystal-rpm](https://github.com/lugia-kun/crystal-rpm).
2. Install the dependencies (`shard install`)
3. Build the app (`shard build`)
   - I recommended `--release` option before, but it takes very very long time now.
4. You can run the built executable from anywhere and/or install to anywhere.

## Usage

### Prerequisites

* (of course) TeX Live's original package database file.
* Template RPM spec file to generate onto.
  - Sections `%prep`, `%build`, major part of `%install`, `%check`, `%changelog`, etc will taken from this file.
* RPM spec file(s) which generates previous version of installation.
  - This file is only for collecting package names which the new installation should obsolete
.
* Binary RPM packages which corresponding above RPM spec file.
  - These packages can be installed or not installed.
* `kpsewhich` command. This command must be installed on the system.
* `texmf.cnf` that comes from previous version of installation. This also must be installed on the system. `kpsewhich` never reads `texmf.cnf` placed at `TEXMFHOME` tree.

### Optional requirements

* `fakechroot` command
  - Create database of RPM without modifying the system.
  - If you choose to install binary packages to be obsoleted, `fakechroot` command is not required.
  - You can use root permission instead, but not strongly recommended.

### Run

The program can be called from anywhere (unless filesystem prevents execution).

```
Usage: tlpsrc2spec --tlpdb=[TLPDB] --template=[Template] --installed=[current]
    -t, --tlpdb=FILE                 TeX Live Package Database file
    -T, --template=FILE              Template RPM Spec file
    -I, --installed=FILE             RPM Spec file used for current installation
    -o, --output=FILE                Output spec file name
    -P, --topdir=DIR                 Read packages from given path
    -L, --log=NAME                   Log file output name
    -v, --verbose                    Be Verbose
    -q, --quiet                      Be Quiet
    -h, --help                       Show this help
```

If `-P` is given, installs them to temporary directory on `/tmp/tlpsrc2spec-rpmdb`. This path can be changed by the `TLPSRC2SPEC_RPMDB` environment variable. In this case, the directory must be created.

If `-P` is used, the program requires `chroot()` available. The build process of creating RPM DB is equivalent to install packages with `rpm -ivh --justdb package.rpm`.

## Development

* Make sure to run `crystal tool format` before commit. Currently no
  hooks are deployed on this repository. Sorry!

## Contributing

1. Fork it (<https://github.com/lugia-kun/tlpsrc2spec/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Hajime Yoshimori](https://github.com/lugia-kun) - creator and maintainer

