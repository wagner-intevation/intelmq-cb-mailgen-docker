#!/bin/bash

set -eu -o pipefail
test -n "${DEBUG-}" && set -x

function end_test {
    read line file <<<$(caller)
    echo "Mailgen test failed at $file:$line."
    # restore original 10shadowservercsv.py script
    $docker intelmq-mailgen mv $script.bak $script
    $docker intelmq-mailgen cp $config.bak $config
    $docker intelmq-mailgen rm /tmp/intelmqcbmail_disabled
}
trap end_test ERR

docker="docker exec --env-file=.env -e DEBUG=${DEBUG-} -ti"
script=/etc/intelmq/mailgen/formats/10shadowservercsv.py
config=/etc/intelmq/intelmq-mailgen.conf

# Check executable itself by calling help page
$docker intelmq-mailgen intelmqcbmail -h

# Manipulate shadowserver rule to allow sending the data right now without waiting
$docker intelmq-mailgen cp $script $script.bak
$docker intelmq-mailgen sed -i 's/minutes=15/seconds=2/' $script
$docker intelmq-mailgen sed -i 's/hours=2/seconds=2/' $script
$docker intelmq-mailgen cp $config $config.bak
$docker intelmq-mailgen sed -i 's/INFO/DEBUG/' $config

cbmail_out=$($docker intelmq-mailgen intelmqcbmail -a)

echo "$cbmail_out" | grep "Calling script '$script'"
echo "$cbmail_out" | grep '1 mails sent'
[[ "$cbmail_out" =~ New\ ticket\ number ]]

$docker intelmq-dsmtpd tail -n 1 /var/log/dsmtpd.log | fgrep ' -> lir@list.bfinv.de [IntelMQ-Mailgen#'

echo "Mailgen tests completed successfully!"

# Restore previous environment
$docker intelmq-mailgen mv $script.bak $script
$docker intelmq-mailgen rm /tmp/intelmqcbmail_disabled
$docker intelmq-mailgen cp $config.bak $config
