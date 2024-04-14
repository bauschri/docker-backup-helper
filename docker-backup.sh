#! /bin/bash

cd "$(dirname "$0")" || exit

TRY_RUN=false

source ".env" || exit
source "_func_helper.sh" || exit

while getopts "a:n:t" opt; do
  case $opt in
  a)
    ACTION=$OPTARG
    ;;
  t)
    export TRY_RUN=true
    ;;
  n)
    export DOCKER_REGEX=$OPTARG
    ;;
  \?)
    echo "Invalid option: -$OPTARG" >&2
    ;;
  esac
done

case $ACTION in
backup)
  source "${PWD}/_func_backup.sh" || exit
  check_backup_vars
  backup_docker
  ;;
list)
  list_docker_images
  ;;
*)
  echo "Invalid action. Use --action [backup, list]"
  ;;
esac
