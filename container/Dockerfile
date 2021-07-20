
FROM python:3.8.0

RUN pip install \
    mlflow==1.18.0 \
    psycopg2 \
    boto3 && \
    mkdir /mlflow/

EXPOSE 5000

CMD mlflow server \
    --host 0.0.0.0 \
    --port 5000 \
    --default-artifact-root ${BUCKET} \
    --backend-store-uri postgresql://${USERNAME}:${PASSWORD}@${HOST}:${PORT}/${DATABASE}