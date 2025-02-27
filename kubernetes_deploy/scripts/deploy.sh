#!/bin/sh
function _deploy() {
  usage="deploy -- deploy image from current commit to an environment
  Usage: kubernetes_deploy/bin/deploy environment [image-tag]
  Where:
    environment [dev|staging|api-sandbox|production]
    [image_tag] any valid ECR image tag for app
  Example:
    # deploy image for current commit to dev
    deploy.sh dev

    # deploy latest image of master to dev
    deploy.sh dev latest

    # deploy latest branch image to dev
    deploy.sh dev <branch-name>-latest

    # deploy specific image (based on commit sha)
    deploy.sh dev <commit-sha>
    "

  # exit when any command fails, keep track of the last for output
  # https://intoli.com/blog/exit-on-errors-in-bash-scripts/
  set -e
  trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
  trap 'echo "\"${last_command}\" command completed with exit code $?."' EXIT

  if [ $# -gt 2 ]
  then
    echo "$usage"
    return 0
  fi

  case "$1" in
    dev | dev-lgfs | staging | api-sandbox | production)
      environment=$1
      ;;
    *)
      echo "$usage"
      return 0
      ;;
  esac

  if [ -z "$2" ]
  then
    current_branch=$(git branch | grep \* | cut -d ' ' -f2)
    current_version=$(git rev-parse $current_branch)
  else
    current_version=$2
  fi

  context=$(kubectl config current-context)
  component=app
  docker_registry=754256621582.dkr.ecr.eu-west-2.amazonaws.com/laa-get-paid/cccd
  docker_image_tag=${docker_registry}:${component}-${current_version}

  printf "\e[33m--------------------------------------------------\e[0m\n"
  printf "\e[33mContext: $context\e[0m\n"
  printf "\e[33mEnvironment: $environment\e[0m\n"
  printf "\e[33mDocker image: $docker_image_tag\e[0m\n"
  printf "\e[33m--------------------------------------------------\e[0m\n"

  kubectl config set-context --current --namespace=cccd-${environment}

  # apply common config
  kubectl apply -f kubernetes_deploy/${environment}/secrets.yaml
  kubectl apply -f kubernetes_deploy/${environment}/app-config.yaml

  # apply new image
  kubectl set image -f kubernetes_deploy/${environment}/deployment.yaml cccd-app=${docker_image_tag} --local --output yaml | kubectl apply -f -
  kubectl set image -f kubernetes_deploy/${environment}/deployment-worker.yaml cccd-worker=${docker_image_tag} --local --output yaml | kubectl apply -f -
  kubectl set image -f kubernetes_deploy/cron_jobs/archive_stale.yaml cronjob-worker=${docker_image_tag} --local --output yaml | kubectl apply -f -

  # apply non-image specific config
  kubectl apply \
    -f kubernetes_deploy/${environment}/service.yaml \
    -f kubernetes_deploy/${environment}/ingress.yaml

  # ECR only exists in one environment and cccd-dev has credentials
  if [[ ${environment} == 'dev' ]]; then
    kubectl apply -f kubernetes_deploy/cron_jobs/clean_ecr.yaml
  fi

  kubectl annotate deployments/claim-for-crown-court-defence kubernetes.io/change-cause="$(date) - deploying: $docker_image_tag via local machine"
  kubectl annotate deployments/claim-for-crown-court-defence-worker kubernetes.io/change-cause="$(date) - deploying: $docker_image_tag via local machine"

  # Forcibly restart the app regardless of whether
  # there are changes - to apply new secrets and configmaps at least.
  # - requires kubectl verion 1.15+
  #
  kubectl rollout restart deployments/claim-for-crown-court-defence
  kubectl rollout restart deployments/claim-for-crown-court-defence-worker

  # wait for rollout to succeed or fail/timeout
  kubectl rollout status deployments/claim-for-crown-court-defence --timeout=600s
  kubectl rollout status deployments/claim-for-crown-court-defence-worker --timeout=600s
}

_deploy $@
