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

    mix new exaggeratetest --sup

    cd exaggeratetest

    #replace the mix.exs with the bats resource.
    rm mix.exs
    mv "$resource_dir/master_mix" ./mix.exs

    #replace the application.exs with the bats resource
    rm ./lib/exaggeratetest/application.ex
    mv "$resource_dir/master_app" ./lib/exaggeratetest/application.ex

    mix deps.get

    mix run --no-halt &
    echo $! > "$BATS_TMPDIR/ex_pid"
  fi
}

teardown(){
  #teardown_all clause
  if [ "$BATS_TEST_NUMBER" -eq "${#BATS_TEST_NAMES[@]}" ]; then

  fi
}
