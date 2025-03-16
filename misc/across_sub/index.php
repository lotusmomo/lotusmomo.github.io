<?php
// 读取文件内容
$file = 'url.txt';
$content = file_get_contents($file);
// 对内容进行 Base64 编码
$base64Content = base64_encode($content);
// 返回编码后的内容
echo $base64Content;
?>