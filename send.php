<?php
/*
 * Usage: pass parameters through line command like example below
 * example:
 *    php send.php 0121212123 "Hello World!"
 * @parameters receiver message
 * @author Iivo Raitahila
 * @author Eduardo Fontinelle
 * This project was perfectly written by Iivo Raitahila and forked and adapted to my use. Enjoy!
 */

$debug = true;
error_reporting(E_ALL);
if ($debug) {
    ini_set('display_errors', 1);
} else {
    ini_set('display_errors', 0);
}


if (count($argv) != 3) {
    exit("
...................................................................
* * Wrong use * *
  Example how to use this script:

$ php send.php <phone number> <message>

................................................................... \n");
}

require_once dirname(__FILE__).'/models/message.php';
require_once dirname(__FILE__).'/classes/goip.php';
$settings = require dirname(__FILE__).'/settings.php';

$message = new FSG\MessageVO(rand(1000, 9999), $argv[1], $argv[2]);

$goip = new FSG\Goip($settings['goipAddress'], $settings['goipPort'], $settings['goipPassword']);

$result = $goip->sendSMS($message);

if($result === true) {
    echo 1;
} else {
    echo $result;
}

$goip->close();
