select choice in "$@"; do
  if [ -n "$choice" ]; then echo "$choice"; break; fi;
done
