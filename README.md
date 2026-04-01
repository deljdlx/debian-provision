# Wsl environment management
Github repository https://github.com/STIMDATA/wsl-debian


## Cloning repository

```
git clone git@github.com:STIMDATA/wsl-debian.git
```




## First install
```
wsl --unregister devenv
wsl --import devenv . snapshots/12-devenv.tar.gz --version 2
wsl --distribution devenv
```

# Take snapshot
```
wsl --export devenv snapshots/12-devenv.tar.gz

```


wsl --export test snapshots/12-devenv.tar.gz

<!-- test copy in clipboard working -->
echo hello world | wl-copy




Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\rebuild.ps1