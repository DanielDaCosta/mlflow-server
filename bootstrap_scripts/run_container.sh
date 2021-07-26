#!/bin/bash

# Env Variables
# Database variables are saved on SSM Parameter Store
ACCOUNT_ID=`aws sts get-caller-identity --output text --query 'Account'`
DB_PASS=`aws ssm get-parameters --region us-east-1 --names /mlflow/DB_PASS --with-decryption --query "Parameters[0].Value" --output text`
DB_HOST=`aws ssm get-parameters --region us-east-1 --names /mlflow/DB_HOST --query "Parameters[0].Value" --output text`
DB_USER=`aws ssm get-parameters --region us-east-1 --names /mlflow/DB_USER --query "Parameters[0].Value" --output text`


# installing docker
sudo yum update -y
sudo amazon-linux-extras install docker
sudo service docker start
sudo usermod -a -G docker ec2-user # Add the ec2-user to the docker group so you can execute Docker commands without using sudo

# Configure Docker to start on boot
sudo systemctl enable docker.service # https://docs.docker.com/engine/install/linux-postinstall/#configure-docker-to-start-on-boot

# Docker commands This means that developers or build scripts using the Docker CLI no
# longer have to explicitly use the ECR API to retrieve a secure token, nor call docker login with this token before pushing or pulling container image.
sudo yum -y  install amazon-ecr-credential-helper # https://aws.amazon.com/blogs/containers/amazon-ecr-credential-helper-now-supports-amazon-ecr-public/

mkdir -p /home/ec2-user/.docker

sudo cat <<-END >> /home/ec2-user/.docker/config.json
{
    "credHelpers": {
        "public.ecr.aws": "ecr-login",
        "${ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/mlflow:latest": "ecr-login"
    }
}
END

# Change the user and/or group ownership of a given file, directory, or symbolic link
chown -R ec2-user:ec2-user /home/ec2-user/.docker
sudo -u ec2-user docker pull $ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/mlflow:latest

# Run Container (Expose port 5000; Restart -always- after reboot)
docker run --env BUCKET=s3://mlflow-artifacts/ --env USERNAME=$DB_USER --env PASSWORD=$DB_PASS \
--env HOST=$DB_HOST --env PORT=5432 --env DATABASE=mlflow \
-p 5000:5000 -d --restart always --name mlflow-server $ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/mlflow:latest
