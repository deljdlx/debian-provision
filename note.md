# Wsl environment management
Git repository git@github.com:STIMDATA/wsl-debian.git


## first install
wsl --unregister devenv
wsl --import devenv . snapshots/06-devenv.tar.gz --version 2
wsl --distribution devenv







wsl --install -d Debian --name devenv


## export wsl to tar file
## delete old tar file if exists
if (Test-Path -Path "devenv.tar.gz") {
    Remove-Item -Path "devenv.tar.gz"
}


<!-- ============================================== -->

wsl --export devenv devenv.tar.gz

## destroy wsl
wsl --unregister devenv

# Import wsl from tar file

wsl --import devenv . devenv.tar.gz --version 2


<!-- ============================================== -->



<!-- # Initialize wsl -->
./init.ps1



## install packages in wsl
 sh ~/provision.sh




## restart wsl
wsl --shutdown

# export wsl
rm devenv.tar.gz
wsl --export devenv devenv.tar.gz

## destroy wsl
wsl --unregister devenv


## recreate wsl from tar file
wsl --import devenv . devenv.tar.gz --version 2

## connect to wsl
wsl --distribution devenv



# save valid image before making changes
rm devenv.tar.gz



del devenv-ok.tar.gzcode

wsl --export devenv devenv.tar.gz
wsl --unregister devenv
wsl --import devenv . devenv.tar.gz --version 2
wsl --distribution devenv



wsl --unregister devenv
wsl --import devenv . snapshots/05-devenv.tar.gz --version 2
wsl --distribution devenv



## Restoe valid image
rm devenv.tar.gz
wsl --unregister devenv
wsl --import devenv . devenv-ok.tar.gz --version 2
wsl --distribution devenv# wsl-debian12
