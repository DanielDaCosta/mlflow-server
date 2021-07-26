# MLflow Server on EC2

Mlflow is an open-source platform to manage the ML lifecycle, including experimentation, reproducibility, deployment, and a central model registry.


## Code Structure

The code was executed on AWS AMI: Amazon Linux 2

### Database/:

Creates the database for Mlflow to store its files:

```CREATE DATABASE mlflow;```

### Container/:

Contains the Dockerfile for building the Image.

The image is built and pushed to the ECR through the Gitlab-CI. Check the gitlab-ci.yml for the full code:
```
docker build -t $DOCKER_REGISTRY/$APP_NAME:latest container/
aws ecr describe-repositories --repository-names $APP_NAME || aws ecr create-repository --repository-name $APP_NAME
aws ecr get-login-password --region $AWS_DEFAULT_REGION | docker login --username AWS --password-stdin $DOCKER_REGISTRY
docker push $DOCKER_REGISTRY/$APP_NAME:latest
 ```

### Shell Script/:
- All secret credentials are stored on AWS SSM under path mlflow/:

```
ACCOUNT_ID=`aws sts get-caller-identity --output text --query 'Account'`
DB_PASS=`aws ssm get-parameters --region us-east-1 --names /mlflow/DB_PASS --with-decryption --query "Parameters[0].Value" --output text`
DB_HOST=`aws ssm get-parameters --region us-east-1 --names /mlflow/DB_HOST --query "Parameters[0].Value" --output text`
DB_USER=`aws ssm get-parameters --region us-east-1 --names /mlflow/DB_USER --query "Parameters[0].Value" --output text`
```

- Installing Docker. Adding ec2-user to the docker group so you can execute Docker commands without using sudo:

```sudo yum update -y
sudo amazon-linux-extras install docker
sudo service docker start
sudo usermod -a -G docker ec2-user
```

- **Configure Docker to start on boot** (https://docs.docker.com/engine/install/linux-postinstall/#configure-docker-to-start-on-boot):

```sudo systemctl enable docker.service```

- **Setting amazon-ecr-credential-helper**: This means that developers or build scripts using the Docker CLI no longer have to explicitly use the ECR API to retrieve a secure token, nor call docker login with this token before pushing or pulling container image. (https://aws.amazon.com/blogs/containers/amazon-ecr-credential-helper-now-supports-amazon-ecr-public/)
```mkdir -p /home/ec2-user/.docker

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
```

- Pulling Images from ECR:

```sudo -u ec2-user docker pull $ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/mlflow:latest
Running container. The container is configured to always restart. Port 5000 is available to services outside of Docker.
docker run --env BUCKET=s3://mlflow-artifacts/ --env USERNAME=$DB_USER --env PASSWORD=$DB_PASS \
--env HOST=$DB_HOST --env PORT=5432 --env DATABASE=mlflow \
-p 5000:5000 -d --restart always --name mlflow-server $ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/mlflow:latest
```

## Usage
After pushing the image to ECR, run the command `bash run_container.sh`; it will build the docker image for you.
