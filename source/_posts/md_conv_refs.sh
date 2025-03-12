#!/bin/bash

# 检查是否提供了文件
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <markdown_file>"
    exit 1
fi

FILE=$1

# 提取所有引用定义 (形如 [1]: URL)
declare -A refs
while IFS= read -r line; do
    if [[ $line =~ ^\[([0-9]+)\]:[[:space:]]*(.*) ]]; then
        refs[${BASH_REMATCH[1]}]=${BASH_REMATCH[2]}
    fi
done < <(grep -E '^\[[0-9]+\]:[[:space:]]*.*' "$FILE")

# 替换所有引用链接
awk -v refs="$(declare -p refs)" '
BEGIN {
    eval refs
}
{
    gsub(/!?\[[^\]]+\]\[[0-9]+\]/, repl);
    print;
}
function repl(match) {
    id = match;
    gsub(/.*\[([0-9]+)\]$/, "\\1", id);
    url = refs[id];
    gsub(/\[([0-9]+)\]/, "(" url ")", match);
    return match;
}' "$FILE"