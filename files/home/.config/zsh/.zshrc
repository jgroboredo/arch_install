if [ "$TERM" = "xterm-color" ] || [ "$TERM" = "xterm-256color" ]; then
    autoload -U colors && colors
    PS1="%{$fg[red]%}%n%{$reset_color%}@%{$fg[blue]%}%m %{$fg[yellow]%}%~ %{$reset_color%}%\\$ "
fi
