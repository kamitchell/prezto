function _terminfo_dir() {
    case `uname` in
        Darwin) echo $HOME/.terminfo ;;
        aix*) echo $HOME/.terminfo-$(uname -s)-$(uname -p) ;;
        *) echo $HOME/.terminfo-$(uname -s)-$(uname -m) ;;
    esac
}

export TERMINFO=$(_terminfo_dir)

[ -d $TERMINFO ] || (mkdir $TERMINFO && find $HOME/.terminfo-src -type f | xargs -n 1 tic -x)
