# MTCLI

A command line client for Movale Type Data API.

## Usage

```bash
$ mtcli add localhost http://localhost/mt/mt-data-api.cgi
$ mtcli current localhost
$ mtcli list_entries --site_id=1 --limit=3 | jq .
```

