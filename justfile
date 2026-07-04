tangle:
  nix shell .#default --command emacs --batch -l ./tangle-script.el

clean:
  rm -f init.el
