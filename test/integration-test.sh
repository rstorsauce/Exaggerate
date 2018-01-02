#!/bin/sh

set -ex

#expected to be run from the project root directory.

wd=`pwd`
resource_dir="$wd/test/resources"

# $1 can be used to specify a different branch, if desired.
# defaults to "develop"
GIT_TAG="$1"
if [ -z "$GIT_TAG" ]; then
  GIT_TAG="develop"
fi

cd "/tmp"

rm -rf exaggeratetest
mix new exaggeratetest --sup

cd exaggeratetest

#replace the mix.exs with the bats resource.
rm mix.exs
cp "$resource_dir/master_mix" ./mix.exs
#replace the application.exs with the bats resource
rm ./lib/exaggeratetest/application.ex
cp "$resource_dir/master_app" ./lib/exaggeratetest/application.ex
#substitute the git tag value
sed -i "s/TAG/$GIT_TAG/" "./mix.exs"

#get dependencies and build the project.
mix deps.get

#pull the swaggerfile.
cp "$resource_dir/test.json" .
#swagger it up!
mix swagger test.json

#overwrite the endpoints file
rm ./lib/test/endpoint.ex
cp "$resource_dir/master_endpoints" ./lib/test/endpoint.ex

mix compile

#check if a previous version is already running

if [ -f /tmp/ex_pid ]; then
  pid=`cat /tmp/ex_pid`
  rm -f /tmp/ex_pid
  kill -KILL "$pid"
fi

mix run --no-halt &
echo $! > /tmp/ex_pid

sleep 5

## ROOT TEST
res=`curl http://localhost:4001/`
[ "$res" = "{\"text\":\"root route\"}" ]

## pathparam test
res=`curl http://localhost:4001/pathparam/value`
[ "$res" = "{\"path parameter\":\"value\"}" ]

##queryparam test
res=`curl http://localhost:4001/queryparam?param=value`
[ "$res" = "{\"query parameter\":\"value\"}" ]
res=`curl http://localhost:4001/queryparam`
[ "$res" = "{\"422\":\"error: required parameter 'param' is missing\"}" ]

##optional queryparam test
res=`curl http://localhost:4001/optionalqueryparam?param=value`
[ "$res" = "{\"query parameter\":\"value\"}" ]
res=`curl http://localhost:4001/optionalqueryparam`
[ "$res" = "{}" ]

##bodyparam test
res=`curl --data "param=value" -X POST http://localhost:4001/bodyparam`
[ "$res" = "{\"body parameter\":\"value\"}" ]

##requestbodyparam single object, json test
res=`curl --data "{\"data\":\"test\"}" -H "Content-Type: application/json" -X POST http://localhost:4001/requestbody_param_single_json`
[ "$res" = "{\"request body parameter\":\"test\"}" ]

pid=`cat /tmp/ex_pid`
rm "/tmp/ex_pid"
kill -KILL $pid

echo "TESTS PASSED."
