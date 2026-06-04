function beet --wraps beet
    command beet -c /config/config.yaml $argv
end
function b --wraps beet
    command beet -c /config/config.yaml $argv
end
function bl --wraps beet
    command beet -c /config/config.yaml ls $argv
end
function bi --wraps beet
    command beet -c /config/config.yaml import $argv
end
function bb --wraps beet
    command beet -c /config/config.yaml bad $argv
end
function bdup --wraps beet
    command beet -c /config/config.yaml duplicates $argv
end
if status --is-interactive; and test "$PWD" = /
    cd /uploads
end
