#!/usr/bin/env bats

setup(){

  #setup_all clause
  if [ "$BATS_TEST_NUMBER" -eq 1 ]; then

    resource_dir="$BATS_TEST_DIRNAME/bats-resources"

    #the "GIT_TAG" environment variable can be set to specify whiat tag to pull
    #the github repo from.
    if [ -z "$GIT_TAG" ]; then
      GIT_TAG="develop"
    fi

    cd "$BATS_TMPDIR"

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
    rm ./lib/test/test.ex
    cp "$resource_dir/master_endpoints" ./lib/test/test.ex

    nohup mix run --no-halt > /dev/null 2> /dev/null < /dev/null &

    echo $! > "$BATS_TMPDIR/ex_pid"
  fi
}

teardown(){
  test_count=${#BATS_TEST_NAMES[@]}
  if [ "$BATS_TEST_NUMBER" -eq "$test_count" ]; then
    pid=`echo $BATS_TMPDIR/ex_pid`
    kill $pid

    rm "$BATS_TMPDIR/ex_pid"
    rm -rf "$BATS_TMPDIR/exaggeratetest"
  fi
}

@test "root route" {
  res=`curl http://localhost:4001/`
  [ res = "root route" ]
}
