<?php

declare(strict_types=1);

$root = dirname(__DIR__, 2);
$src = $root . '/web/app/plugins/redis-cache/includes/object-cache.php';
$dest = $root . '/web/app/object-cache.php';

if (!is_file($src)) {
    return;
}

if (!copy($src, $dest)) {
    fwrite(STDERR, "Failed to copy Redis object cache drop-in\n");
    exit(1);
}

fwrite(STDOUT, "Enabled Redis object cache drop-in\n");
