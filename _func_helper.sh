#!/bin/bash

execute_cmd() {
  tar_cmd=$1

  if [ "$TRY_RUN" = true ]; then
    echo "Would run: $tar_cmd"
  else
    eval $tar_cmd
  fi
}
