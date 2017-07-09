#mkdir -p keys
#ssh-keygen -f keys/chaturbate
#sudo chmod 600 keys/chaturbate

docker rm -f terraform

docker run -i -t \
  --name=terraform \
  --volume=${PWD}:/data \
  --workdir=/data \
  hashicorp/terraform:full \
  $@ \
    -var-file="vars/secret.tfvars" \
    -var-file="vars/common.tfvars" \
    -var-file="vars/production.tfvars"