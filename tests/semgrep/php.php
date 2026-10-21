<?php
// REQ-149: fixtures for template/.semgrep/php.yml (semgrep --test in check-scaffold.sh).
function fixtures($userInput, $data) {
    // ruleid: php-eval
    eval($userInput);
    // ruleid: php-os-command
    system("ls " . $userInput);
    // ruleid: php-os-command
    shell_exec($userInput);
    // ok: php-os-command
    system("ls -l");
    // ruleid: php-unserialize
    unserialize($data);
    // ok: php-unserialize
    unserialize($data, ["allowed_classes" => false]);
    // ruleid: php-include-from-input
    include $_GET["page"];
    // ruleid: php-include-from-input
    require $_POST["module"];
    // ok: php-include-from-input
    include "header.php";
}
