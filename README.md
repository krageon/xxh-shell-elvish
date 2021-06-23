## Install
```
xxh +I xxh-shell-elvish+git+https://github.com/krageon/xxh-shell-elvish
```
Connect:
```
xxh myhost +s elvish
```
To avoid adding `+s` every time use xxh config in `~/.config/xxh/config.xxhc` (`$XDG_CONFIG_HOME`):
```
hosts:
  ".*":                     # Regex for all hosts
    +s: elvish
```

## Plugins
In theory these can exist, but I haven't figured out a smooth way to make them work with elvish yet. Possible a wrapper script that loads multiple scripts in sequence, who knows. Some day :)

## Thanks
The [the xxh shell example](https://github.com/xxh/xxh-shell-example) for showing me where to start.
