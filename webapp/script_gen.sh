#!/bin/bash

#echo -ne '' > js_gen.sh
#chmod +x js_gen.sh
#exec >> js_gen.sh

function do_snippet()
{
    [ -e "$1/.gen/html" ] || return
    if [ -e "$1/.gen/check.sh" ]; then
    echo "sh <<EOF"
    cat "$1/.gen/check.sh"
    echo -ne "\nEOF\n"
    echo '[ $? -eq 0 ] && cat <<EOF'
    else
    echo "cat <<EOF"
    fi
    echo -ne "buttons_html+=\\\`"
    sed "s/#SWUNAME#/$1/g" "$1/.gen/html"
    echo "\\\`;"
    echo "EOF"
}

cd swu
echo -ne "#!/bin/sh\n\n"
echo 'exec > js/swubuttons.min.js'
echo "echo 'buttons_html=\`\`;'"
for swud in *; do
  if [ -d "$swud/.gen" ]; then
    do_snippet $swud
  fi
done

