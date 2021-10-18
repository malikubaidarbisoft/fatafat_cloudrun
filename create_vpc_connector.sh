#Using default network
gcloud compute networks vpc-access connectors create my-connector \
--network default \
--region $REGION \
--range 10.8.0.0/28 \
--min-instances 1 \
--max-instances 2 