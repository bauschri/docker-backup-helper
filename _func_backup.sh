#!/bin/bash

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  shopt -s globstar
fi

check_backup_vars() {
  if [[ "$DOCKER_REGEX" == "" ]]; then
    echo "--regex is required"
    exit 1
  fi

  if [[ "$BACKUP_DIR" == "" ]]; then
    echo "BACKUP_DIR is required"
    exit 1
  fi
}

detect_docker_images_for_backup() {
  all_docker_images=$(docker ps -q | xargs docker inspect --format='{{.Name}}' | cut -f2 -d/)
  docker_images_for_backup=()

  for image in $all_docker_images; do
    if [[ $image =~ $DOCKER_REGEX ]]; then
      docker_images_for_backup+=("$image")
    fi
  done

  if [ ${#docker_images_for_backup[@]} -eq 0 ]; then
    echo "No Docker images match the provided regex."
    exit 1
  fi
}

remove_old_docker_images() {
  for docker_name in "${docker_images_for_backup[@]}"; do
    echo "Remove old docker images for $docker_name"
    backup_dir_docker="$BACKUP_DIR"/"$docker_name"
    mkdir -p "$backup_dir_docker"

    files=$(ls "$backup_dir_docker"/*.{tar.gz,txt} >/dev/null 2>&1)

    for file in $files; do
      cmd="rm \"$file\""
      execute_cmd "$cmd"
    done
  done
}

backup_docker_inspect() {
  for docker_name in "${docker_images_for_backup[@]}"; do
    container_data="$(docker inspect "$docker_name")"
    echo "$container_data" >"$BACKUP_DIR/$docker_name/INSPECT_CONFIG_$docker_name.txt"
  done
}

backup_docker_images() {
  for docker_name in "${docker_images_for_backup[@]}"; do
    docker_image="$(docker inspect --format='{{.Config.Image}}' "$docker_name")"
    save_file="$BACKUP_DIR/$docker_name/IMAGE_$docker_name.tar"

    echo "Backup DOCKER IMAGE $docker_image to $save_file.gz"

    execute_cmd "docker save -o \"$save_file\" \"$docker_image\" | gzip > \"$save_file\".gz"

    execute_cmd "rm \"$save_file\""
  done
}

backup_docker_bind_volumes() {
  for docker_name in "${docker_images_for_backup[@]}"; do
    docker_bind_volumes="$(docker inspect -f '"{{.Name}}""{{.Mounts}}"' "$docker_name" | grep -oE 'bind\s+[^ ]+' | awk '{print $2}' | awk '{ printf "%s;",$1 }')"

    for docker_bind_volume in ${docker_bind_volumes//;/ }; do

      SKIP_VOLUME_NAMES=('/var/run/docker.sock')
      if [[ " ${SKIP_VOLUME_NAMES[*]} " =~ ${docker_bind_volume} ]]; then
        continue
      fi

      docker_bind_volume_name=$(echo "$docker_bind_volume" | sed 's/\//_/g')
      save_file="$BACKUP_DIR/$docker_name/VOLUME_BIND_${docker_name}_${docker_bind_volume_name}.tar.gz"

      echo "Backup BIND Volume $docker_name $save_file"
      cmd="tar czf $save_file -C $docker_bind_volume $BACKUP_DIR/$docker_name >/dev/null 2>&1"
      execute_cmd "$cmd"
    done

  done
}

backup_docker() {
  detect_docker_images_for_backup
  echo "Backup Images: ${docker_images_for_backup[*]}"

  remove_old_docker_images

  backup_docker_inspect

  backup_docker_images

  backup_docker_bind_volumes
}
