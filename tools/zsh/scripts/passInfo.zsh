#! /usr/bin/zsh
# display password information for all users

user_list=($(cut -d: -f1 /etc/passwd))
for user in $user_list; do
    echo "Password information for $user"
    if sudo chage -l $user 2>/dev/null; then
        echo "----------"
    else
        echo "No password information available"
        echo "----------"
    fi
done
