# MTCLI

A command line client for Movale Type Data API.

## Installation

```bash
$ git clone https://github.com/masiuchi/mtcli
$ cd mtcli
$ gem build mtcli.gemspec
$ gem install --local mtcli-0.0.1.gem
```

## Usage

```bash
$ mtcli add localhost http://localhost/mt/mt-data-api.cgi
$ mtcli current localhost
$ mtcli list_entries --site_id=1 --limit=3 | jq .
```

